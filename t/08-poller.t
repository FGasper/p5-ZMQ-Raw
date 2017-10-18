#!perl

use Socket qw(PF_INET SOCK_STREAM pack_sockaddr_in inet_aton);
use Test::More;
use ZMQ::Raw;

my $poller = ZMQ::Raw::Poller->new;
isa_ok ($poller, "ZMQ::Raw::Poller");

my $ctx = ZMQ::Raw::Context->new;
my $req = ZMQ::Raw::Socket->new ($ctx, ZMQ::Raw->ZMQ_REQ);
my $rep = ZMQ::Raw::Socket->new ($ctx, ZMQ::Raw->ZMQ_REP);
my $unknown = ZMQ::Raw::Socket->new ($ctx, ZMQ::Raw->ZMQ_REP);

ok (!eval {$poller->add, 'bad', ZMQ::Raw->ZMQ_POLLIN});

$poller->add ($req, ZMQ::Raw->ZMQ_POLLIN);
$poller->add ($rep, ZMQ::Raw->ZMQ_POLLIN);

is 0, $poller->wait (100);

ok (defined ($poller->events ($req)));
ok (defined ($poller->events ($rep)));
ok (!defined ($poller->events ($unknown)));

my $events = $poller->events ($req);
is $events, 0;

$events = $poller->events ($rep);
is $events, 0;

$rep->bind ('tcp://127.0.0.1:5557');
$req->connect ('tcp://localhost:5557');
$req->send ('hello');

is 1, $poller->wait (100);
$events = $poller->events ($req);
is $events, 0;

$events = $poller->events ($rep);
is $events, ZMQ::Raw->ZMQ_POLLIN;

$rep->recv();
$rep->send ('world');

is 1, $poller->wait (100);
$events = $poller->events ($req);
is $events, ZMQ::Raw->ZMQ_POLLIN;

$events = $poller->events ($rep);
is $events, 0;

is 1, $poller->wait (100);
$req->recv();
is 0, $poller->wait (100);

$poller = ZMQ::Raw::Poller->new;

socket (my $tcp, PF_INET, SOCK_STREAM, 0);
ok ($tcp);

$poller->add ($tcp, ZMQ::Raw->ZMQ_POLLIN);
is 0, $poller->wait (100);

ok (connect ($tcp, pack_sockaddr_in (5557, inet_aton ("127.0.0.1"))));
is 1, $poller->wait (100);

$events = $poller->events ($tcp);
is $events, ZMQ::Raw->ZMQ_POLLIN;

recv ($tcp, my $buf, 16384, 0);
is 0, $poller->wait (100);

close $tcp;

done_testing;

