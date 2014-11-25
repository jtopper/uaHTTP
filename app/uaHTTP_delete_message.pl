### uaHTTP delete message functions ###

### Functions ###

sub delete_message {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder})  || die "No folder passed to delete_message\n";
defined($form{message}) || die "No message passed to delete_message\n";

$request = clean EDF::Object("request", \"message_delete");
$request->addChild("messageid", $form{message});
$request->addChild("folderid", $form{folder});

$response = $handle->request($request);

$request->DESTROY;

die "Message #$form{message} does not exist\n" if ($response->value eq "message_not_exist"); 
die "Folder #$form{folder} does not exist\n" if ($response->value eq "folder_not_exist"); 
die "Access to folder #$form{folder} invalid\n" if ($response->value eq "folder_access_invalid"); 

unless ($response->value eq "message_delete") {
  die "Unknown response: " . $response->value . "\n";
}

my %data = ( "folder" => $form{folder}, "message" => -1 );

$uaresponse->root;

return &display_folder($handle, \%data, $uaresponse, $username);

}

###
1;
