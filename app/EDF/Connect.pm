package EDF::Connect;

use IO::Socket;
use EDF::Object;
use EDF::Object::String;
use Data::Dumper;

@ISA = (IO::Socket);

my %Read_stack;
my $Lockdir;
my $Announcedir = './.announcements';

if (-e $Announcedir) {
  if (-d $Announcedir) {
    unlink <$Announcedir/*>;
  } else {
    print STDERR "Announcements disabled; $Announcedir is not a directory\n";
    undef $Announcedir;
  }
} else {
  if (! mkdir($Announcedir, 0666)) {
    print STDERR "Announcements disabled; $Announcedir could not be created\n";
    undef $Announcedir;
  }
}

###

sub import {

my %imports;

shift; # Remove the module name from the variable list

foreach (@_) {
  my($name, $value) = split(/:/, $_, 2);
  $imports{lc $name} = $value;
}

if (exists $imports{"locking"}) {
  $Lockdir = $imports{"locking"} || './.locks';
  &initialiseLocking;
}

}

###

sub initialiseLocking {

if (defined($Lockdir)) {
  if (-e $Lockdir) {
    if (-d $Lockdir) {
      unlink <$Lockdir/*>;
    } else {
      print STDERR "Handle locking disabled; $Lockdir is not a directory\n";
      undef $Lockdir;
    }
  } else {
    if (! mkdir($Lockdir, 0666)) {
      print STDERR "Handle locking disabled; $Lockdir could not be created\n";
      undef $Lockdir;
    }
  }
  print STDERR "Handle locking enabled ($Lockdir)\n" if (defined $Lockdir);
} else {
  print STDERR "Handle locking disabled\n";
}

}

###

sub new {

my $object = shift;
my $class = ref($object) || $object;

my $addr = shift || "localhost";
my $port = shift || 23;

my $socket = IO::Socket::INET->new(
                        Proto    => "tcp",
                        PeerAddr => $addr,
                        PeerPort => $port,
                    )
or die "Cannot connect to $addr:$port\n";

bless ($socket, $class);

$Read_stack{$socket} = "";

$socket->connect;

return $socket;

};

###

sub connect {

### Initiate EDF connexion

my $handle = shift;
my $request;
my $response;

$request = clean EDF::Object("edf", \"on");

$handle->write($request->toEDF, "\r\n") || return undef;

$response = parseEDF EDF::Object($handle);

return 1;

}

###

sub close {

my $handle = shift;

delete $Read_stack{$handle};
unlink "$Announcedir/$handle";

#$handle->shutdown(2);

}

###

sub write {

my $handle = shift;
my $string = join("", @_);

my $wrote;
my $length;

while ($length = length($string)) {
  $wrote = $handle->syswrite($string, $length);
  return undef unless (defined($wrote));
  last if ($wrote == $length);
  substr($string, 0, $wrote) = "";
}

return 1;

}

###

sub request {

my $handle  = shift;
my $request = shift;
my $response = undef;
my $retries = 100;

print "ASSERT LOCK $$\n";
$handle->assertLock || return undef;

if ($handle->write($request->toEDF)) {

  print "Request written [", $request->toEDF, "]\n";

  for (;;) {
    print "Waiting for response\n";
    $response = parseEDF EDF::Object($handle);
    last unless (defined $response);
    print "Response read [", substr($response->toEDF, 0, 60), "]\n";
    last if ($response->name =~ /^(?:reply|edf)$/i);
    addAnnouncement($handle, $response);
    $response->DESTROY;
  }

} else {

  print "Request write error\n";

}

print "RELEASE LOCK $$\n";
$handle->releaseLock || die "Something has gone very wrong with file locking\n";

return $response;

}

###

sub addAnnouncement {

return unless ($Announcedir);

my ($handle, $response) = @_;

open(ANNOUNCEMENT, ">> $Announcedir/$handle") || die "Cannot open '$Announcedir/$handle' for appending: $!";
print ANNOUNCEMENT $response->toEDF, "\000";
close(ANNOUNCEMENT);

return 1;

}

###

sub readAnnouncements {

return unless ($Announcedir);

my $handle = shift;
my $announcementfile = "$Announcedir/$handle";
my $newannouncementfile = "$Announcedir/$handle.NEW";
my @announcements = ();

return unless (-e $announcementfile);

local $/ = "\000";

open(ANNOUNCEMENT, $announcementfile);
open(NEWANNOUNCEMENT, "> $newannouncementfile") || die "Cannot open '$newannouncementfile' for writing: $!";
while (my $announcement = <ANNOUNCEMENT>) {
  my $edf  = parseString EDF::Object::String($announcement);
  push(@announcements, $edf);
  if ( (time - $edf->root->child('announcetime')->value) < 600) {
    my $edfstring = $edf->toEDF;
    substr($edfstring, -3, 0, '<_seen=1/>') unless ($edf->root->first("_seen"));
    print NEWANNOUNCEMENT $edfstring, "\000";
  }
}
close(NEWANNOUNCEMENT);
close(ANNOUNCEMENT);

if (-e $newannouncementfile) {
  rename($newannouncementfile, $announcementfile) || die "Could not rename '$newannouncementfile' to '$announcementfile': $!";
}

return @announcements;

}

###

sub readByte {

my $handle = shift;
my $string;
my $code;
my $timeout = 100;

### Quicker way for only one byte

BYTELOOP:
{

  $code = $handle->sysread($string, 1);

#  print "R:$code:$string\n";

  unless ($code) {
    select(undef, undef, undef, 0.1);
    print  "#$timeout ";
    redo BYTELOOP if (--$timeout);
    return undef;
  }

}

return $string;

###

unless (length $Read_stack{$handle}) {

  $handle->sysread($string, 1);
  return undef unless(length $string);
  $Read_stack{$handle} = $string; 

}

return substr($Read_stack{$handle}, 0, 1, "");

}

###

sub dumpStack {

my $handle = shift;

return $Read_stack{$handle};

}

###

sub assertLock {

my $handle  = shift;
my $retries = shift || 100;
my $process;

return 1 unless(defined($Lockdir)); # If handle locking is disabled act there is nothing to do here.

my $lockfile = "$Lockdir/$handle";

{
  while (-e $lockfile) {
    print STDERR "HANDLE LOCKED $$\n";
    sleep(1);
    #select(undef, undef, undef, 1); # sleep 1000ms and try lock again
    return undef unless($retries--);
  }

  open(LOCK, "> $lockfile");
  print LOCK $$;
  CORE::close(LOCK);

  open(LOCK, $lockfile);
  $process = <LOCK>;
  CORE::close(LOCK);

  redo if ($process != $$);

}

return 1;

}

###

sub releaseLock {

my $handle = shift;

return 1 unless(defined($Lockdir)); # If handle locking is disabled there is nothing to do here.

my $lockfile = "$Lockdir/$handle";

open(LOCK, $lockfile);
$process = <LOCK>;
CORE::close(LOCK);

if ($process != $$) {
  print STDERR "Not your lock to release\n";
  return undef;
}

unlink $lockfile;

return 1;

}

###
1;
