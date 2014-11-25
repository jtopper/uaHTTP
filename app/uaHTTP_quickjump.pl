### uaHTTP quickjump functions ###

### Functions ###

sub quickjump {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html, %data);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$uaresponse->root;

my $entry = $form{searchbox};

$entry =~ s/^\s+//;
$entry =~ s/\s+$//;

if ($entry !~ /\D/) { # only digits therefore a message

  $request = clean EDF::Object("request", \"message_list");
  $request->addChild("messageid", $entry);
  $response = $handle->request($request);
  $request->DESTROY;

  die "Message #$entry does not exist\n" if ($response->value eq "message_not_exist"); 

  unless ($response->value eq "message_list") {
    die "Unknown response: " . $response->value . "\n";
  }

  my $reply = { $response->elements };

  %data = ( "folder" => $reply->{folderid}[0], "message" => $entry, "openfolder" => 1 );

  return &display_message($handle, \%data, $uaresponse, $username);

} elsif ($entry =~ s/^\?\s*//) { # search request

  %data = ( "query" => $entry );

  return &display_search_results($handle, \%data, $uaresponse, $username);

} else { # a user name

  $request = clean EDF::Object("request", \"user_list");
  $request->addChild("name", \"$entry");
  $response = $handle->request($request);
  $request->DESTROY;

  my $reply = { $response->elements };

  my $userid = $reply->{user}[0];

  if ($userid) {
    %data = ( "user" => $userid );
    return &display_userinfo($handle, \%data, $uaresponse, $username);
  }

  die "User $entry does not exist\n"; 

}

}

###
1;
