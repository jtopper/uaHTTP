### uaHTTP user edit functions ###

### Functions ###

sub change_description {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $toid);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$request = clean EDF::Object("request", \"user_edit");
$request->addChild("userid", $userid);
$request->addChild("description", \"$form{'description'}");
$response = $handle->request($request);
$request->DESTROY;

die("Could not change entry\n") unless ($response->value eq "user_edit");

my %data = ( "user" => $userid );

$uaresponse->root;

return &display_userinfo($handle, \%data, $uaresponse, $username);

}

#
1;

