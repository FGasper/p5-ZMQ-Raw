package ZMQ::Raw::Loop;

use strict;
use warnings;
use Carp;

sub CLONE_SKIP { 1 }

my @attributes;

BEGIN
{
	@attributes = qw/
		context
		poller
		timers
		handles
		promises
		events
		terminated
	/;

	no strict 'refs';
	foreach my $accessor (@attributes)
	{
		*{$accessor} = sub
		{
			@_ > 1 ? $_[0]->{$accessor} = $_[1] : $_[0]->{$accessor}
		};
	}
}

use ZMQ::Raw;
use ZMQ::Raw::Loop::Event;
use ZMQ::Raw::Loop::Handle;
use ZMQ::Raw::Loop::Promise;
use ZMQ::Raw::Loop::Timer;

=head1 NAME

ZMQ::Raw::Loop - Loop class

=head1 DESCRIPTION

A L<ZMQ::Raw::Loop> represents an event loop.

B<WARNING>: The API of this module is unstable and may change without warning
(any change will be appropriately documented in the changelog).

=head1 METHODS

=head2 new( )

Create a new event loop

=head2 run( )

Run the event loop

=head2 run_one( )

Run until a single event occurs

=head2 add( )

TBC

=head2 terminate( )

Terminate the event loop

=cut

sub new
{
	my ($this, $context) = @_;

	my $class = ref ($this) || $this;
	my $self =
	{
		context => $context,
		poller => ZMQ::Raw::Poller->new,
		timers => [],
		handles => [],
		events => [],
		promises => [],
	};

	return bless $self, $class;
}

sub run
{
	my ($this) = @_;

	$this->terminated (0);
	while (!$this->terminated)
	{
		if (!$this->run_one)
		{
			# nothing left, terminate
			$this->terminate();
		}
	}

	$this->_cancel_timers();
	$this->_cancel_events();
	$this->_cancel_handles();
	$this->_clear_promises();
}



sub run_one
{
	my ($this) = @_;

	if ($this->poller->size)
	{
		if ($this->poller->wait (-1))
		{
			$this->_dispatch_events() || $this->_dispatch_handles() || $this->_dispatch_timers();

			$this->promises ([grep { $_->status == ZMQ::Raw::Loop::Promise->PLANNED } @{$this->promises}]);
		}

		return 1;
	}

	return 0;
}



sub add
{
	my ($this, $item) = @_;

	if (ref ($item) eq 'ZMQ::Raw::Loop::Timer')
	{
		$this->_add_timer ($item);
	}
	elsif (ref ($item) eq 'ZMQ::Raw::Loop::Handle')
	{
		$this->_add_handle ($item);
	}
	elsif (ref ($item) eq 'ZMQ::Raw::Loop::Event')
	{
		$this->_add_event ($item);
	}
	elsif (ref ($item) eq 'ZMQ::Raw::Loop::Promise')
	{
		$this->_add_promise ($item);
	}
	else
	{
		croak "don't know how to add $item";
	}
}



sub _add_timer
{
	my ($this, $timer) = @_;

	$timer->done (0);
	$timer->loop ($this);
	$this->poller->add ($timer->timer->socket, ZMQ::Raw->ZMQ_POLLIN);

	push @{$this->timers}, $timer;
}



sub _add_event
{
	my ($this, $event) = @_;

	$event->done (0);
	$event->loop ($this);
	$this->poller->add ($event->read_handle, ZMQ::Raw->ZMQ_POLLIN);

	if ($event->timeout)
	{
		$event->timer (ZMQ::Raw::Timer->new ($this->context,
			after => $event->timeout)
		);
		$this->poller->add ($event->timer->socket, ZMQ::Raw->ZMQ_POLLIN);
	}

	push @{$this->events}, $event;
}



sub _add_promise
{
	my ($this, $promise) = @_;

	push @{$this->promises}, $promise;
}



sub _add_handle
{
	my ($this, $handle) = @_;

	my $events = 0;
	if ($handle->on_readable)
	{
		$events |= ZMQ::Raw->ZMQ_POLLIN;
	}
	if ($handle->on_writable)
	{
		$events |= ZMQ::Raw->ZMQ_POLLOUT;
	}
	if ($handle->timeout)
	{
		$handle->timer (ZMQ::Raw::Timer->new ($this->context,
			after => $handle->timeout)
		);
		$this->poller->add ($handle->timer->socket, ZMQ::Raw->ZMQ_POLLIN);
	}

	$handle->done (0);
	$handle->loop ($this);
	$this->poller->add ($handle->handle, $events);

	push @{$this->handles}, $handle;
}



sub _dispatch_handles
{
	my ($this) = @_;

	foreach my $handle (@{$this->handles})
	{
		my $events = $this->poller->events ($handle->handle);
		if ($events)
		{
			$handle->done (1);
			$this->handles ([grep { !$_->done } @{$this->handles}]);

			$this->poller->remove ($handle->handle);

			if ($handle->timer)
			{
				$handle->timer->cancel();
				$this->poller->remove ($handle->timer->socket);
			}

			if ($events & ZMQ::Raw->ZMQ_POLLIN)
			{
				my $readable = $handle->on_readable;
				&{$readable} ($handle) if $readable;
			}
			elsif ($events & ZMQ::Raw->ZMQ_POLLOUT)
			{
				my $writable = $handle->on_writable;
				&{$writable} ($handle) if $writable;
			}
		}
		elsif ($handle->timer)
		{
			my $events = $this->poller->events ($handle->timer->socket);
			if ($events)
			{
				$handle->done (1);
				$this->handles ([grep { !$_->done } @{$this->handles}]);

				$this->poller->remove ($handle->handle);
				$this->poller->remove ($handle->timer->socket);

				$handle->timer->socket->recv;
				my $timeout = $handle->on_timeout;
				&{$timeout} ($handle) if $timeout;
			}
		}

		return 1 if $handle->done;
	}

	return 0;
}



sub _dispatch_events
{
	my ($this) = @_;

	foreach my $event (@{$this->events})
	{
		my $events = $this->poller->events ($event->read_handle);
		if ($events)
		{
			$event->done (1);
			$this->events ([grep { !$_->done } @{$this->events}]);

			$this->poller->remove ($event->read_handle);

			if ($event->timer)
			{
				$event->timer->cancel();
				$this->poller->remove ($event->timer->socket);
			}

			my $set = $event->on_set;
			&{$set} ($event) if $set;
		}
		elsif ($event->timer)
		{
			my $events = $this->poller->events ($event->timer->socket);
			if ($events)
			{
				$event->done (1);
				$this->events ([grep { !$_->done } @{$this->events}]);

				$this->poller->remove ($event->read_handle);
				$this->poller->remove ($event->timer->socket);

				$event->timer->socket->recv;
				my $timeout = $event->on_timeout;
				&{$timeout} ($event) if $timeout;
			}
		}

		return 1 if $event->done;
	}

	return 0;
}



sub _dispatch_timers
{
	my ($this) = @_;

	foreach my $timer (@{$this->timers})
	{
		my $socket = $timer->timer->socket;
		my $events = $this->poller->events ($socket);
		if ($events)
		{
			$this->poller->remove ($socket);
			$socket->recv;

			my $timeout = $timer->on_timeout;
			&{$timeout} ($timer) if ($timeout);

			if (!$timer->timer->running())
			{
				$timer->done (1);
				$this->timers ([grep { !$_->done } @{$this->timers}]);
			}
			else
			{
				$this->poller->add ($socket, ZMQ::Raw->ZMQ_POLLIN);
			}

			return 1;
		}
	}

	return 0;
}



sub _cancel_timers
{
	my ($this) = @_;

	foreach my $timer (@{$this->timers})
	{
		my $socket = $timer->timer->socket;
		$this->poller->remove ($socket);
	}

	$this->timers ([]);
}



sub _cancel_events
{
	my ($this) = @_;

	foreach my $event (@{$this->events})
	{
		my $events = $this->poller->events ($event->read_handle);
		$this->poller->remove ($event->read_handle);

		if ($event->timer)
		{
			$event->timer->cancel();
			$this->poller->remove ($event->timer->socket);
		}
	}

	$this->events ([]);
}



sub _cancel_handles
{
	my ($this) = @_;

	foreach my $handle (@{$this->handles})
	{
		$this->poller->remove ($handle->handle);

		if ($handle->timer)
		{
			$handle->timer->cancel();
			$this->poller->remove ($handle->timer->socket);
		}
	}

	$this->handles ([]);
}



sub _clear_promises
{
	my ($this) = @_;

	$this->promises ([]);
}



sub terminate
{
	my ($this) = @_;
	$this->terminated (1);
}

=for Pod::Coverage context handles events poller timers promises terminated

=head1 AUTHOR

Jacques Germishuys <jacquesg@striata.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2017 Jacques Germishuys.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of ZMQ::Raw::Loop
