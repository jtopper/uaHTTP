### uaHTTP display page functions ###

### Functions ###

sub display_page {

my ($handle, $content, $uaresponse, $username) = @_;
my ($response, $request, $html);

my %form = %$content;

#my $canonname = $uaresponse->child("name")->value;
#my $userid    = $uaresponse->first("userid")->value;

my $tousername = "";

if ($form{'user'}) {
  $request = clean EDF::Object("request", \"user_list");
  $request->addChild("searchtype", 0);
  $request->addChild("userid", $form{'user'});
  $response = $handle->request($request);

  $tousername = $response->value if ($response->first("user")->child("name"));
}

$html .= qq~
<html>
<head>
<title>New Page</title>

<link rel=stylesheet type="text/css" href="ua.css">

<script language="Javascript">
<!--

function setEntrypoint() {

~;

$html .= ($tousername)?"document.entryForm.replytext.focus();":"document.entryForm.pageuser.focus();";

$html .= qq~

}

// -->
</script>

</head>

<body onLoad="setEntrypoint()">
<form action="sendpage" method="post" name="entryForm">
<table width="100%" border="0" cellspacing="0" cellpadding="0" class="headers"><tr>
<td><table border="0" cellspacing="0" cellpadding="0" class="title"><tr>
<td>To:&nbsp;</td><td class="htext"><input class="headinput" type="text" name="pageuser" value="$tousername" size="80"></td>
</tr></table></td>
</tr><tr width="100%">
<td colspan="2"><textarea name="replytext" rows="16" wrap="virtual" cols="78" class="messagemono"></textarea></td>
</tr><tr>
<td class="title" style="padding-left: 8px">Redirect if busy/not on:&nbsp;<input type="checkbox" name="redirect" value="1" checked></td>
<td class="buttonhole"><input type="submit" name="Submit" value="Send page" class="button"></td>
</tr></table>
</form>
</body>
</html>
~;

return $html;

}

###
1;
