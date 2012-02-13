#!/bin/sh

# update classpath
OSCARS_CLASSPATH="."
for f in "$AXIS2_HOME"/lib/*.jar
do
 OSCARS_CLASSPATH="$OSCARS_CLASSPATH":$f
done
OSCARS_CLASSPATH="$OSCARS_CLASSPATH":OSCARS-client-api.jar:OSCARS-client-examples.jar

url=$2

if [  $# -lt 2  ]
 then
    echo "run.sh createReservation|signal|list|query|cancel [url] [request-specific-params]"
elif [ $1 == "createReservation" ] && [ $# -eq 2 ] && [ $2 != "-help" ]
 then
    echo $2
    java -cp $OSCARS_CLASSPATH -Djava.net.preferIPv4Stack=true CreateReservationClient repo $url
elif [  $1 == "createReservation"  ]
 then
    java -cp $OSCARS_CLASSPATH -Djava.net.preferIPv4Stack=true CreateReservationCLI $*
elif [ $1 == "signal"  ]
 then    
    java -cp $OSCARS_CLASSPATH -Djava.net.preferIPv4Stack=true SignalClient repo $url $3 $4 $5 $6
elif [ $1 == "query"  ]
 then    
    java -cp $OSCARS_CLASSPATH -Djava.net.preferIPv4Stack=true QueryReservationCLI $*
elif [ $1 == "list"  ]
 then    
    java -cp $OSCARS_CLASSPATH -Djava.net.preferIPv4Stack=true ListReservationCLI $*
elif [ $1 == "cancel"  ]
 then    
    java -cp $OSCARS_CLASSPATH -Djava.net.preferIPv4Stack=true CancelReservationCLI $*
elif [ $1 == "topology"  ]
 then    
    java -cp $OSCARS_CLASSPATH -Djava.net.preferIPv4Stack=true GetNetworkTopologyClient repo $url
else
    echo "Please specify 'createReservation', 'signal', 'list', 'query', or 'cancel'"
fi

