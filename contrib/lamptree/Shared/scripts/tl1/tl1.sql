CREATE TABLE ps_tl1_interfaces (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  host VARCHAR(32) NOT NULL,
  aid VARCHAR(32) NOT NULL,
  aid_type VARCHAR(8) NOT NULL
);

CREATE TABLE ps_tl1_counters (
  interface_id INTEGER NOT NULL,
  type VARCHAR(5) NOT NULL,
  value VARCHAR(32) NOT NULL,
  validity VARCHAR(10) NOT NULL,
  location VARCHAR(10) NOT NULL,
  direction VARCHAR(10) NOT NULL,
  time_period VARCHAR(10) NOT NULL,
  start_time INTEGER NOT NULL,
  UNIQUE (interface_id, type, start_time, time_period, direction),
  FOREIGN KEY (interface_id) references ps_tl1_interfaces(id));

CREATE TRIGGER ps_tl1_counters_interface_id_fki
  BEFORE INSERT ON ps_tl1_counters FOR EACH ROW
  BEGIN
    SELECT RAISE(ROLLBACK, 'Insert on ps_tl1_counters violates foreign key on interface_id')
    WHERE 
      (SELECT id FROM ps_tl1_interfaces WHERE id = NEW.interface_id)
        IS NULL;
  END;

CREATE TABLE ps_tl1_alarms (
  interface_id INTEGER NOT NULL,
  condition_type VARCHAR(10) NOT NULL,
  severity VARCHAR(2) NOT NULL,
  service_affecting BOOLEAN NOT NULL,
  time INTEGER NOT NULL,
  description VARCHAR(32) NOT NULL,
  location VARCHAR(4) NOT NULL,
  supplemental VARCHAR(32) NOT NULL,
  UNIQUE (interface_id, condition_type, time),
  FOREIGN KEY (interface_id) references ps_tl1_interfaces(id));

CREATE TRIGGER ps_tl1_alarms_interface_id_fki
  BEFORE INSERT ON ps_tl1_alarms FOR EACH ROW
  BEGIN
    SELECT RAISE(ROLLBACK, 'Insert on ps_tl1_alarms violates foreign key on interface_id')
    WHERE 
      (SELECT id FROM ps_tl1_interfaces WHERE id = NEW.interface_id)
        IS NULL;
  END;

CREATE TABLE ps_tl1_states (
  interface_id INTEGER NOT NULL,
  start_time INTEGER NOT NULL,
  end_time INTEGER NOT NULL,
  primary_state VARCHAR(10) NOT NULL,
  secondary_state VARCHAR(10) NOT NULL,
  UNIQUE (interface_id, start_time, end_time),
  FOREIGN KEY (interface_id) references ps_tl1_interfaces(id));

CREATE TRIGGER ps_tl1_states_interface_id_fki
  BEFORE INSERT ON ps_tl1_states FOR EACH ROW
  BEGIN
    SELECT RAISE(ROLLBACK, 'Insert on ps_tl1_states violates foreign key on interface_id')
    WHERE 
      (SELECT id FROM ps_tl1_interfaces WHERE id = NEW.interface_id)
        IS NULL;
  END;


