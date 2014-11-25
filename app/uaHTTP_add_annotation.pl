### uaHTTP add annoation functions ###

### Functions ###

sub add_annotation {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $toid);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder})  || die "No folder passed to add_annotation\n";
defined($form{message}) || die "No message passed to add_annotation\n";

$request = clean EDF::Object("request", \"message_edit");
$request->addChild("folderid", $form{folder});
$request->addChild("messageid", $form{message});
$request->add("attachment", \"add");
$request->addChild("content-type", \'text/x-ua-annotation');
$request->addChild("text", \$form{annotation});

$response = $handle->request($request);

$request->DESTROY;

die("Posting error\n") unless ($response->value eq "message_edit");

my %data = ( "folder" => $form{folder}, "message" => $response->child("messageid")->value );

$uaresponse->root;

return &display_message($handle, \%data, $uaresponse, $username);

}
#
1;

