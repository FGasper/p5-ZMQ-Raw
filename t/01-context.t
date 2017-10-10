#!perl

use Test::More;
use ZMQ::Raw;

is 0, ZMQ::Raw->ZMQ_PAIR;
is 1, ZMQ::Raw->ZMQ_PUB;
is 2, ZMQ::Raw->ZMQ_SUB;
is 3, ZMQ::Raw->ZMQ_REQ;
is 4, ZMQ::Raw->ZMQ_REP;
is 5, ZMQ::Raw->ZMQ_DEALER;
is 6, ZMQ::Raw->ZMQ_ROUTER;
is 7, ZMQ::Raw->ZMQ_PULL;
is 8, ZMQ::Raw->ZMQ_PUSH;
is 9, ZMQ::Raw->ZMQ_XPUB;
is 10, ZMQ::Raw->ZMQ_XSUB;
is 11, ZMQ::Raw->ZMQ_STREAM;

is 1, ZMQ::Raw->ZMQ_DONTWAIT;
is 2, ZMQ::Raw->ZMQ_SNDMORE;

is 1, ZMQ::Raw->ZMQ_MORE;
is 3, ZMQ::Raw->ZMQ_SHARED;

is 1, ZMQ::Raw->ZMQ_POLLIN;
is 2, ZMQ::Raw->ZMQ_POLLOUT;
is 4, ZMQ::Raw->ZMQ_POLLERR;
is 8, ZMQ::Raw->ZMQ_POLLPRI;

is 1, ZMQ::Raw->ZMQ_IO_THREADS;
is 2, ZMQ::Raw->ZMQ_MAX_SOCKETS;
is 3, ZMQ::Raw->ZMQ_SOCKET_LIMIT;
is 3, ZMQ::Raw->ZMQ_THREAD_PRIORITY;
is 4, ZMQ::Raw->ZMQ_THREAD_SCHED_POLICY;
is 5, ZMQ::Raw->ZMQ_MAX_MSGSZ;

ok (ZMQ::Raw->ZMQ_EVENT_CONNECTED);
ok (ZMQ::Raw->ZMQ_EVENT_CONNECT_DELAYED);
ok (ZMQ::Raw->ZMQ_EVENT_CONNECT_RETRIED);
ok (ZMQ::Raw->ZMQ_EVENT_LISTENING);
ok (ZMQ::Raw->ZMQ_EVENT_BIND_FAILED);
ok (ZMQ::Raw->ZMQ_EVENT_ACCEPTED);
ok (ZMQ::Raw->ZMQ_EVENT_ACCEPT_FAILED);
ok (ZMQ::Raw->ZMQ_EVENT_CLOSED);
ok (ZMQ::Raw->ZMQ_EVENT_CLOSE_FAILED);
ok (ZMQ::Raw->ZMQ_EVENT_DISCONNECTED);
ok (ZMQ::Raw->ZMQ_EVENT_MONITOR_STOPPED);
ok (ZMQ::Raw->ZMQ_EVENT_ALL);

my $ctx = ZMQ::Raw::Context->new;
isa_ok ($ctx, "ZMQ::Raw::Context");

$ctx->set (ZMQ::Raw->ZMQ_MAX_SOCKETS, 1024);

done_testing;

