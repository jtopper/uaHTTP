var isIE = false;
var isIE55 = false;
var isNS = false;
var isNS6 = false;

if (navigator.appVersion.indexOf("MSIE") != -1){
  isIE = true;
  temp = navigator.appVersion.split("MSIE")
  if (parseFloat(temp[1]) >= 5.5) {
    isIE55 = true;
  }
} else {
  var agt=navigator.userAgent.toLowerCase(); 
  if ( ( (agt.indexOf('mozilla') != -1) || (agt.indexOf('opera') != -1) ) &&
       (agt.indexOf('spoofer') == -1) &&
       (agt.indexOf('compatible') == -1) &&
       (agt.indexOf('webtv') == -1)
      ) {
    isNS = true;
    if (parseInt(navigator.appVersion) >= 5) {
      isNS6 = true;
    }
  }
}

var origtext = "";

function stitchurls() {

if (xhasstitchurls) {

  xmessagebox = document.getElementById("messagebox");
  mtext = xmessagebox.innerHTML;
  //mtext = xmessagebox.parentNode.innerHTML;
  if (document.getElementById("stitchcheck").checked) {
    origtext = mtext;
    mtext = " " + mtext;
    marray = mtext.split(/<a /i);
    re = /(<a[\s\S]+?href=")([\s\S]+?)(")([\s\S]+?)<\/a><br>([\s\S]+?)( |<p>|<\/p>)/ig;
    for (x = 1; x < marray.length; x++) {
        marray[x] = "<a " + marray[x];
        newtext = marray[x].replace(re, "$1$2$5$3$4$5$6</a>");
        marray[x] = newtext;
    }
    newmtext = marray.join("");
  } else {
    newmtext = origtext || mtext;
  }
  xmessagebox.innerHTML = newmtext;
  //xmessagebox.parentNode.innerHTML = newmtext;

}

}

