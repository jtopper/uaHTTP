### uaHTTP process vote functions ###

### Functions ###

sub process_vote {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $toid);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder})  || die "No folder passed to process_vote\n";
defined($form{message}) || die "No message passed to process_vote\n";

if (defined $form{voteid}) {

  $request = clean EDF::Object("request", \"message_vote");
  $request->addChild("folderid",  $form{folder});
  $request->addChild("messageid", $form{message});
  $request->addChild("voteid",    $form{voteid});

  $response = $handle->request($request);

  $request->DESTROY;

  die("Posting error\n") unless ($response->value eq "message_vote");

}

my %data = ( "folder" => $form{folder}, "message" => $form{message} );

$uaresponse->root;

return &display_message($handle, \%data, $uaresponse, $username);

}
#
1;

