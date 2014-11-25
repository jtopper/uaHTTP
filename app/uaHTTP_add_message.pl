### uaHTTP add message functions ###

### Functions ###

sub add_message {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $toid);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder}) || die "No folder passed to add_message\n";

if (defined $form{toname}) {

  $request = clean EDF::Object("request", \"user_list");
  $request->addChild("searchtype", 0);
  $request->addChild("name", \$form{toname});

  $response = $handle->request($request);

  $toid = $response->value if ($response->first("user"));

  $request->DESTROY;
}

$request = clean EDF::Object("request", \"message_add");
$request->addChild("folderid", $form{folder});
$request->addChild("replyid", $form{message}) if ($form{message});

if ($toid) {
  $request->addChild("toid", $toid);
} elsif (defined $form{toname}) {
  $request->addChild("toname", \$form{toname});
}

$request->addChild("subject", \$form{subject}) if (defined $form{subject});
$request->addChild("text", \$form{messagetext});

$request->addChild("replyfolder", $form{replyfolder}) unless ($form{replyfolder} == $form{folder});

$response = $handle->request($request);

$request->DESTROY;

die("Posting error\n") unless ($response->value eq "message_add");

my %data = ( "folder" => $form{folder}, "message" => $response->child("messageid")->value );

$uaresponse->root;

return &display_message($handle, \%data, $uaresponse, $username);

}
#
1;

