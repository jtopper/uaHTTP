### uaHTTP send page functions ###

### Functions ###

sub send_page {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

#my $canonname = $uaresponse->child("name")->value;
#my $userid    = $uaresponse->first("userid")->value;

$request = clean EDF::Object("request", \"user_list");
$request->addChild("searchtype", 0);
$request->addChild("name", \"$form{'pageuser'}");
$response = $handle->request($request);

my $touserid = $response->value if ($response->first("user"));
my $tousername = ($response->child("name"))?$response->value:$form{'pageuser'};

$request = clean EDF::Object("request", \"user_contact");
$request->addChild("toid", $touserid);
$request->addChild("text", \"$form{'replytext'}");
$response = $handle->request($request);

my $close = 0;
my $redirect = $form{'redirect'};

my $htmlmessage;

my $diverttext = ($form{'redirect'})?"- diverting to Private":"- discarding page";

foreach ($response->value) {

  m/^user_contact$/		&& do { $htmlmessage  = "Page sent to $tousername"; $close = 1; $redirect = 0;					last };
  m/^user_not_exist$/		&& do { $htmlmessage  = "'$tousername' is not a UA username";							last };
  m/^user_not_on$/		&& do { $htmlmessage  = "$tousername is not logged on $diverttext";						last };
  m/^user_busy$/		&& do { $htmlmessage  = "$tousername is busy ";
                                        $htmlmessage .= "(" . $response->value . ")" if ($response->child("statusmsg"));
                                        $htmlmessage .= " $diverttext";										last };
  m/^user_contact_invalid$/	&& do { $htmlmessage  = "$tousername may not be contacted $diverttext";						last };
  m/^user_contact_nocontact$/	&& do { $htmlmessage  = "$tousername is not contactable $diverttext";						last };
				   do { $htmlmessage  = "Could not send page ($_)";								last };
}

if ($redirect) {
  $request->addChild("subject", \"Diverted Page");
  $request->addChild("divert", 1);
  $response = $handle->request($request);
}

$close &&= $form{'reply'};

$html .= qq~
<html>
<head>
<title>Page sent</title>

<link rel=stylesheet type="text/css" href="ua.css">
~;

$html .= qq~
<script language="JavaScript">
<!--
parent.close();
// -->
</script>
~ if ($close);

$html .= qq~</head>
<body>

<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><div class="message"><br>$htmlmessage<br><br></div></td>
</tr></table>

</body>
</html>
~;

return $html;

}

###
1;

