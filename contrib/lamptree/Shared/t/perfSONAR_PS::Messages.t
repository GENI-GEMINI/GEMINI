use Test::More 'no_plan';
use Data::Compare;
use XML::LibXML;

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

use_ok('perfSONAR_PS::Messages');
use perfSONAR_PS::Messages;
use perfSONAR_PS::Common;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Messages::getResultMessage tests

$id = genuid();
$idRef = genuid();
$type = "foo";
$content = "<nmwg:metadata />";

$result = getResultMessage($id, $idRef, $type, $content);
$expected = "<nmwg:message xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"" . $id . "\" messageIdRef=\"" . $idRef . "\" type=\"" . $type . "\">\n  " . $content . "</nmwg:message>\n";

ok(compareXML($result, $expected), "Messages::getResultMessage");

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Messages::getResultCodeMessage

$id = genuid();
$idRef = genuid();
$type = "foo";
$result = "This is the result";
$description = "This is the descirption";

$result2 = getResultCodeMessage($id, $idRef, $type, $result, $description);
$expected2 = "<nmwg:message xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"" . $id . "\" messageIdRef=\"" . $idRef . "\" type=\"" . $type . "\">\n    <nmwg:metadata id=\"[0-9]+\">\n    <nmwg:eventType>" . $result . "</nmwg:eventType>\n  </nmwg:metadata>\n  <nmwg:data id=\"[0-9]+\" metadataIdRef=\"\[0-9]+\">\n    <nmwgr:datum xmlns:nmwgr=\"http://ggf.org/ns/nmwg/result/2.0/\">" . $description . "</nmwgr:datum>\n  </nmwg:data>\n</nmwg:message>\n";

ok($result2 =~ /^$expected2$/, "Messages::getResultCodeMessage");

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Messages::getResultCodeMetadata

$id = genuid();
$event = genuid();

$result3 = getResultCodeMetadata($id, $event);
$expected3 = "  <nmwg:metadata id=\"" . $id . "\">\n    <nmwg:eventType>" . $event . "</nmwg:eventType>\n  </nmwg:metadata>\n";

ok(compareXML($result3, $expected3), "Messages::getResultCodeMetadata");

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Messages::getResultCodeData

$id = genuid();
$metaRefId = genuid();
$description = "This is the descirption";

$result4 = getResultCodeData($id, $metaRefId, $description);
$expected4 = "  <nmwg:data id=\"" . $id . "\" metadataIdRef=\"". $metaRefId . "\">\n    <nmwgr:datum xmlns:nmwgr=\"http://ggf.org/ns/nmwg/result/2.0/\">" . $description . "</nmwgr:datum>\n  </nmwg:data>\n";

ok(compareXML($result4, $expected4), "Messages::getResultCodeData");

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";


sub compareXML
{
	#meh, hopefully we can come up with some real xml comparisons but for
	#now we'll just check if the strings are equal
	return $_[0] eq $_[1];
}
