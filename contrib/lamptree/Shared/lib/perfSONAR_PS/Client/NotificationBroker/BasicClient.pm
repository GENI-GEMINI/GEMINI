package perfSONAR_PS::Client::NotificationBroker::BasicClient;

use strict;
use warnings;

use Cwd;
use Log::Log4perl qw(get_logger);
use Data::Dumper;

use perfSONAR_PS::Utils::ParameterValidation;

use fields 'LOGGER', 'CLIENT_DIR', 'AXIS2_DIR';

sub new {
        my ($class) = @_;

        my $self = fields::new($class);

        $self->{LOGGER} = get_logger($class);

        return $self;
}

sub init {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { oscars_client => 1, axis2_home => 1 } );

    unless ($parameters->{oscars_client}) {
        $self->{LOGGER}->error("Must specify directory location of the OSCARS Notification client");
        return -1;
    }

    if (not $parameters->{axis2_home} and not $ENV{"AXIS2_HOME"}) {
        $self->{LOGGER}->error("Must specify directory location of the OSCARS Notification client");
        return -1;
    }

    if ($parameters->{axis2_home}) {
        $self->{AXIS2_DIR} = $parameters->{axis2_home};
    } else {
        $self->{AXIS2_DIR} = $ENV{"AXIS2_HOME"};
    }

    $self->{CLIENT_DIR} = $parameters->{oscars_client};

    return 0;
}

sub getClasspath {
    my ($self) = @_;

    my $classpath = ".";

    if (!defined $self->{AXIS2_DIR} or $self->{AXIS2_DIR} eq "") {
	$self->{LOGGER}->error("Environmental variable AXIS2_HOME undefined");
	return undef;
    }

    my $dir = $self->{AXIS2_DIR}."/lib";

    opendir(DIR, $dir);
    while((my $entry = readdir(DIR))) {
        if ($entry =~ /\.jar$/) {
            $classpath .= ":$dir/$entry";
        }
    }
    closedir(DIR);
    $classpath .= ":".$self->{CLIENT_DIR}."/examples/OSCARS-client-examples.jar";
    $classpath .= ":".$self->{CLIENT_DIR}."/OSCARS-client-api.jar";

    return $classpath;
}

sub exec {
    my ($cmd,$input) = @_;
    my $pid;
    my @lines = ();

    pipe(PC_READER, PC_WRITER);
    pipe(CP_READER, CP_WRITER);
    if ($pid = fork()) {
        close(CP_WRITER);
        close(PC_READER);
        foreach my $line (@{ $input }) {
            print PC_WRITER $line;
            sleep(1);
        }
        while(<CP_READER>) {
            push @lines, $_;
        }

        waitpid($pid, 0);
    } else {
        close(PC_WRITER);
        close(CP_READER);
        open(STDOUT, ">&", \*CP_WRITER);
        open(STDERR, ">&", \*CP_WRITER);
        open(STDIN, ">&", \*PC_READER);
        exec $cmd;
    }

    return \@lines;
}

sub subscribe {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { broker => 1, source => 1, sink => 1, topics => 0, filter => 0 } );

    # Get the java class path
    my $classpath = $self->getClasspath();
    if (not $classpath) {
        return undef;
    }

    my $prev_dir = cwd;

    chdir($self->{CLIENT_DIR}."/examples");

    my $cmd = "java -cp $classpath -Djava.net.preferIPv4Stack=true SubscribeClient -repo ".$self->{CLIENT_DIR}."/examples/conf/axis-tomcat -url ".$parameters->{broker}." -producer ".$parameters->{source} . " -consumer ".$parameters->{sink};

    if ($parameters->{topics}) {
        my $topics = join(",", @{ $parameters->{topics} });
	$self->{LOGGER}->info("Topics: ".$topics);
        $cmd .= " -topics $topics";
    }

    if ($parameters->{filter}) {
        $cmd .= " -message ".$parameters->{filter};
    }

    $self->{LOGGER}->info($cmd);

    $self->{LOGGER}->debug("Before Exec");

    open(EXEC, "-|", $cmd);

    my $uid;
    while(<EXEC>) {
        chomp;

        if (/Subscription Id: (.*)$/) {
            $uid = $1;
        }
    }

    close(EXEC);

    $self->{LOGGER}->debug("UID: $uid") if ($uid);

    return $uid;
}

sub renew {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { broker => 1, reservation_id => 1 } );

    # Get the java class path
    my $classpath = $self->getClasspath();
    if (not $classpath) {
        return undef;
    }

    my $prev_dir = cwd;

    chdir($self->{CLIENT_DIR}."/examples");

    my $cmd = "java -cp $classpath -Djava.net.preferIPv4Stack=true RenewClient -repo ".$self->{CLIENT_DIR}."/examples/conf/axis-tomcat -url ".$parameters->{broker}." -id ".$parameters->{reservation_id};

    open(EXEC, "-|", $cmd);

    my $found_uid;
    while(<EXEC>) {
        chomp;

        if (/Subscription Id: (.*)$/) {
            $found_uid = $1;
        }
    }

    close(EXEC);

    chdir($prev_dir);

    return ($found_uid and ($found_uid eq $parameters->{reservation_id}));
}

sub unsubscribe {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { broker => 1, reservation_id => 1 } );

    # Get the java class path
    my $classpath = $self->getClasspath();
    if (not $classpath) {
        return undef;
    }

    my $prev_dir = cwd;

    chdir($self->{CLIENT_DIR}."/examples");

    my $cmd = "java -cp $classpath -Djava.net.preferIPv4Stack=true UnsubscribeClient -repo ".$self->{CLIENT_DIR}."/examples/conf/axis-tomcat -url ".$parameters->{broker}." -id ".$parameters->{reservation_id};

    open(EXEC, "-|", $cmd);

    my $found_uid;
    while(<EXEC>) {
        chomp;

        if (/Subscription Id: (.*)$/) {
            $found_uid = $1;
        }
    }

    close(EXEC);

    chdir($prev_dir);

    return ($found_uid and ($found_uid eq $parameters->{reservation_id}));
}

sub pause {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { broker => 1, reservation_id => 1 } );

    # Get the java class path
    my $classpath = $self->getClasspath();
    if (not $classpath) {
        return undef;
    }

    my $prev_dir = cwd;

    chdir($self->{CLIENT_DIR}."/examples");

    my $cmd = "java -cp $classpath -Djava.net.preferIPv4Stack=true PauseSubscriptionClient -repo ".$self->{CLIENT_DIR}."/examples/conf/axis-tomcat -url ".$parameters->{broker}." -id ".$parameters->{reservation_id};

    open(EXEC, "-|", $cmd);

    my $found_uid;
    while(<EXEC>) {
        chomp;

        if (/Subscription Id: (.*)$/) {
            $found_uid = $1;
        }
    }

    close(EXEC);

    chdir($prev_dir);

    return ($found_uid and ($found_uid eq $parameters->{reservation_id}));
}

sub resume {
    my ($self, @params) = @_;
    my $parameters = validateParams( @params, { broker => 1, reservation_id => 1 } );

    # Get the java class path
    my $classpath = $self->getClasspath();
    if (not $classpath) {
        return undef;
    }

    my $prev_dir = cwd;

    chdir($self->{CLIENT_DIR}."/examples");

    my $cmd = "java -cp $classpath -Djava.net.preferIPv4Stack=true ResumeSubscriptionClient -repo ".$self->{CLIENT_DIR}."/examples/conf/axis-tomcat -url ".$parameters->{broker}." -id ".$parameters->{reservation_id};

    open(EXEC, "-|", $cmd);

    my $found_uid;
    while(<EXEC>) {
        chomp;

        if (/Subscription Id: (.*)$/) {
            $found_uid = $1;
        }
    }

    close(EXEC);

    chdir($prev_dir);

    return ($found_uid and ($found_uid eq $parameters->{reservation_id}));
}

1;
