### uaHTTP change user message functions ###

### Functions ###

sub change_message {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request);

my %form = %$content;

my $canonname = $uaresponse->child("name")->value;
my $userid    = $uaresponse->first("userid")->value;

$request = clean EDF::Object("request", \"user_edit");
$request->add("login");

if (defined $form{'message'}) {
  $request->addChild("status", Login(LOGIN_BUSY));
  $request->addChild("statusmsg", \"$form{'message'}");
} else {
  $request->addChild("status", Login(LOGIN_ON));
  $request->addChild("statusmsg");
}
$response = $handle->request($request);
$request->DESTROY;

delete($form{'message'});

return "folders?" . join("&", map { "$_=$form{$_}" } keys %form);

}

###
1;

