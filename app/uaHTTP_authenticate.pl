### uaHTTP authentication functions ###

### Functions ###

sub extract_authorisation {

my $request = shift;

return $request->headers->authorization_basic("uaHTTP");

}

###

sub request_authorisation {

my ($connect, $request) = @_;

&process_request($connect, $request, undef, undef, "", "authorisation");

return;

}

###

sub check_authorisation {

my ($username, $password, $host) = @_;
my $retries = 10;
my $response;

my $hostname = gethostbyaddr(inet_aton($host), AF_INET);
my $hostaddr = join('.', unpack('C4', gethostbyname($host) ) );

return (undef, undef) unless (defined $username);

my $handle = new EDF::Connect($UA, $UA_PORT) || die "Cannot connect to UA ($UA:$UA_PORT)\n";

my $request = clean EDF::Object("request", \"user_login");
$request->addChild("name", \"$username");
$request->addChild("password", \"$password");
#$request->addChild("status", Login(LOGIN_NOCONTACT));
$request->addChild("status", Login(LOGIN_BUSY));
$request->addChild("statusmsg", \":is connected through uaHTTP");
$request->addChild("client", \"uaHTTP");
$request->addChild("hostname", \"$hostname") if ($hostname);
$request->addChild("address", \"$hostaddr") if ($hostaddr);
$request->addChild("protocol", \"2.6");
$request->addChild("force", 1);

while (1) {
  $response = $handle->request($request) || return (undef, undef);

  while ($response->name eq "edf") {
     $response = parseEDF EDF::Object($handle);
  }

  if ($response->value eq "user_login") {

    my $userid = $response->first("userid")->value;

    if ($response->first("folders")->child("editor")) {
      do {
        $EDITOR{$userid}{$response->value} = 1;
      } while ($response->next("editor"));
    }

    return ($handle, $response->root);

  }

  if ( ($response->value eq "user_login_already_on") && $retries-- ) {
    sleep(1);
    redo;
  }

  return (undef, undef);

}

}

###

sub check_handle {

my $handle = shift;
my $request = clean EDF::Object("edf", \"echo");

my $response = $handle->request($request);

if (defined $response) { 
#  print "EDFON: ", $response->toEDF, "\n\n";
  return $handle;
} else {
  print "Lost connexion to UA\n" ;
  return undef;
}

$request->DESTROY;

}

###
1;

