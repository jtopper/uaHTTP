### uaHTTP unset nocontact status flag functions ###

### Functions ###

sub unset_nocontact {

my ($handle, undef, $uaresponse) = @_;
my ($response, $request);

my $userid = $uaresponse->first("userid")->value;

if ($handle->request(clean EDF::Object('request', \'user_list')->addChild('searchtype', 1)->addChild('userid', $userid))->child('user')->child('login')->child('status')->value & 2) {

  $request = clean EDF::Object("request", \"user_edit");
  $request->add("login");
  $request->addChild("status", Login(LOGIN_ON));
  $request->addChild("statusmsg");
  $response = $handle->request($request);
  $request->DESTROY;

}

return 1;

}

###
1;

