### uaHTTP move message functions ###

### Functions ###

sub move_message {

local $handle = shift;
my ($content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder})  || die "No folder passed to move_message\n";
defined($form{message}) || die "No message passed to move_message\n";

$request = clean EDF::Object("request", \"message_move");
$request->addChild("folderid", $form{folder});
$request->addChild("moveid", $form{moveid});

$request->addChild("messageid",
  ($form{'option'} == 3)?
    get_ancestor(@form{"message", "folder"}):
    $form{message}
);

if ($form{'option'} > 1) {
  $request->addChild("movetype", ($form{'option'} == 4)?2:1);
}

$response = $handle->request($request);

$request->DESTROY;

die "Message #$form{message} does not exist\n" if ($response->value eq "message_not_exist"); 
die "Folder #$form{folder} does not exist\n" if ($response->value eq "folder_not_exist"); 
die "Access to folder #$form{folder} invalid\n" if ($response->value eq "folder_access_invalid"); 

unless ($response->value eq "message_move") {
  die "Unknown response: " . $response->value . "\n";
}

my %data = ( "folder" => $form{folder}, "message" => -1 );

$uaresponse->root;

return &display_folder($handle, \%data, $uaresponse, $username);

}

###
1;
