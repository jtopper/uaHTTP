### uaHTTP display subscribe functions ###

### Functions ###

sub subscribe {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

defined($form{folder}) || die "No folder passed to display_subscribe\n";

if ($form{subscribe}) {
  $request = clean EDF::Object("request", \"folder_subscribe");
} else {
  $request = clean EDF::Object("request", \"folder_unsubscribe");
}

$request->addChild("folderid", $form{folder});
$response = $handle->request($request);
$request->DESTROY;

die "Folder #$form{folder} does not exist\n" if ( $response->value eq "folder_not_exist" );

return ( ($response->value eq "folder_subscribe") || ($response->value eq "folder_unsubscribe") );

}

###
1;
