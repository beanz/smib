#!/usr/bin/perl

use strict;
use warnings;

use POE qw(Component::IRC);
use IPC::System::Simple qw(capture);
use String::Escape qw(printable);

my $nickname = 'smibtest';
my $ircname  = 'So Make It Bot';
my $programsdir = '/home/xbmc/irccat-commands/';
my $server   = 'holmes.freenode.net';
my @channels = ('#smibtest');

#create a new PoCo-IRC object
my $irc = POE::Component::IRC->spawn(nick    => $nickname,
                                     ircname => $ircname,
                                     server  => $server,
) or die "Cannot make POE-IRC object: $!";

POE::Session->create(package_states => [main => [ qw(_default _start irc_001 irc_public) ],],
                     heap           => { irc => $irc },);

$poe_kernel->run();

sub _start {
  my $heap = $_[HEAP];

  # retrieve our component's object from the heap where we stashed it
  my $irc = $heap->{irc};

  $irc->yield( register => 'all' );
  $irc->yield( connect => { } );
  return;
}

sub irc_001 {
  my $sender = $_[SENDER];

  # Since this is an irc_* event, we can get the component's object by
  # accessing the heap of the sender. Then we register and connect to the
  # specified server.
  my $irc = $sender->get_heap();

  print "Connected to ", $irc->server_name(), "\n";

  # we join our channels
  $irc->yield( join => $_ ) for @channels;
  return;
}

# like when someone says somthing in a channel
sub irc_public {
  my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];

  #this launches commands in public context
  my @output;
  if ($what =~ m/\?(\w+) {0,1}(.*)/) {
    #damn it Benjie I told you file extensions were daft
    my $command = $1;
    my @commands = capture('find', "$programsdir", '-type', 'f', '-name', "$command\.*");
    if (@commands < 1) {
      $irc->yield( privmsg => $channel => "Sorry $nick, I don't have a $command command." );
      return;
    }
    $command = shift @commands;
    my $argline = printable($2);
    chomp $command;
    chdir $programsdir;
    @output = capture("$command", "$nick", "$channel", "$channel", "$argline"); #capture does not invoke a shell if it has more than one argument
  }
  for my $line (@output) {
    $irc->yield( privmsg => $channel => $line );
  }
  return;
}

# This will catch everything we don't and offer clues about what to catch
sub _default {
   my ($event, $args) = @_[ARG0 .. $#_];
   my @output = ( "$event: " );

  for my $arg (@$args) {
    if ( ref $arg eq 'ARRAY' ) {
       push( @output, '[' . join(', ', @$arg ) . ']' );
    }
    else {
      push ( @output, "'$arg'" );
    }
  }
  print join ' ', @output, "\n";
  return;
}