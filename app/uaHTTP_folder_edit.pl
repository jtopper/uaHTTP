### uaHTTP folder edit functions ###

### Functions ###

sub change_infofile {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $toid);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$request = clean EDF::Object("request", \"folder_edit");
$request->addChild("folderid", $form{'folder'});
$request->add("info");
$request->addChild("text", \"$form{'infofile'}");
$response = $handle->request($request);
$request->DESTROY;

die("Could not change entry\n") unless ($response->value eq "folder_edit");

my %data = ( "folder" => $form{'folder'} );

$uaresponse->root;

return &display_folderinfo($handle, \%data, $uaresponse, $username);

}

#
1;

