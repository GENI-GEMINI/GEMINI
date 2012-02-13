#!/bin/sh

#!/bin/sh

rm -f *.rng *.xsd

JAVA=/usr/lib/jvm/java-1.5.0-sun/jre/bin/java
TRANG=/home/jason/ami/perfSONARBUOY/schema/verify/trang.jar
JING=/home/jason/ami/perfSONARBUOY/schema/verify/jing.jar
MSV=/home/jason/ami/perfSONARBUOY/schema/verify/msv.jar

SCHEMA_DIR=.
INSTANCE_DIR=.


# test snmp instance
rm -f *rng *xsd

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/EchoRequest.rnc $SCHEMA_DIR/EchoRequest.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/EchoRequest.rng $SCHEMA_DIR/EchoRequest.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/EchoRequest.rng $INSTANCE_DIR/EchoRequest.xml
#$JAVA -jar $JING $SCHEMA_DIR/EchoRequest.rng $INSTANCE_DIR/EchoRequest.xml

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/EchoResponse.rnc $SCHEMA_DIR/EchoResponse.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/EchoResponse.rng $SCHEMA_DIR/EchoResponse.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/EchoResponse.rng $INSTANCE_DIR/EchoResponse.xml
#$JAVA -jar $JING $SCHEMA_DIR/EchoResponse.rng $INSTANCE_DIR/EchoResponse.xml

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/LSRegisterRequest.rnc $SCHEMA_DIR/LSRegisterRequest.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/LSRegisterRequest.rng $SCHEMA_DIR/LSRegisterRequest.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/LSRegisterRequest.rng $INSTANCE_DIR/LSRegisterRequest.xml
#$JAVA -jar $JING $SCHEMA_DIR/LSRegisterRequest.rng $INSTANCE_DIR/LSRegisterRequest.xml

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/LSRegisterRequest.rnc $SCHEMA_DIR/LSRegisterRequest.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/LSRegisterRequest.rng $SCHEMA_DIR/LSRegisterRequest.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/LSRegisterRequest.rng $INSTANCE_DIR/LSRegisterRequest.xml
#$JAVA -jar $JING $SCHEMA_DIR/LSRegisterRequest.rng $INSTANCE_DIR/LSRegisterRequest.xml

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/MetadataKeyRequest.rnc $SCHEMA_DIR/MetadataKeyRequest.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/MetadataKeyRequest.rng $SCHEMA_DIR/MetadataKeyRequest.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/MetadataKeyRequest.rng $INSTANCE_DIR/MetadataKeyRequest.xml
#$JAVA -jar $JING $SCHEMA_DIR/MetadataKeyRequest.rng $INSTANCE_DIR/MetadataKeyRequest.xml

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/MetadataKeyResponse.rnc $SCHEMA_DIR/MetadataKeyResponse.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/MetadataKeyResponse.rng $SCHEMA_DIR/MetadataKeyResponse.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/MetadataKeyResponse.rng $INSTANCE_DIR/MetadataKeyResponse.xml
#$JAVA -jar $JING $SCHEMA_DIR/MetadataKeyResponse.rng $INSTANCE_DIR/MetadataKeyResponse.xml

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/SetupDataRequest.rnc $SCHEMA_DIR/SetupDataRequest.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/SetupDataRequest.rng $SCHEMA_DIR/SetupDataRequest.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/SetupDataRequest.rng $INSTANCE_DIR/SetupDataRequest.xml
#$JAVA -jar $JING $SCHEMA_DIR/SetupDataRequest.rng $INSTANCE_DIR/SetupDataRequest.xml

$JAVA -jar $TRANG -I rnc -O rng $SCHEMA_DIR/SetupDataResponse.rnc $SCHEMA_DIR/SetupDataResponse.rng
$JAVA -jar $TRANG -I rng -O xsd $SCHEMA_DIR/SetupDataResponse.rng $SCHEMA_DIR/SetupDataResponse.xsd
#$JAVA -jar $MSV -warning $SCHEMA_DIR/SetupDataResponse.rng $INSTANCE_DIR/SetupDataResponse.xml
#$JAVA -jar $JING $SCHEMA_DIR/SetupDataResponse.rng $INSTANCE_DIR/SetupDataResponse.xml


