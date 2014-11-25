### uaHTTP page recovery functions ###

### Functions ###

sub recover_pages {

print LOG "Recovering " . scalar(localtime) . "\n";

foreach my $username (keys %handle) {

  my $handle = $handle{$username};

  my $connect = $handle->[0];
  my $uaresponse = $handle->[1];

  next unless (check_handle($connect));

  my $userid = $uaresponse->root->first("userid")->value if ($uaresponse);

  foreach $announcement ($connect->readAnnouncements) {

    my %element = $announcement->root->elements;

    next if ($element{'_seen'}[0]);
    next unless ($announcement->value =~ /^user_page/);

    $request = clean EDF::Object("request", \"user_contact");
    $request->addChild("toid", $userid);
    $request->addChild("text", \"$element{'text'}[0]");
    $request->addChild("subject", \"Recovered page from $element{'fromname'}[0]");
    $request->addChild("divert", 1);
    $response = $connect->request($request);

    $request->DESTROY;
    $response->DESTROY;

  }

}

}

###
1;
