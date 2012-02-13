------------------------------------------------- The part below is for collection and pinger MA----------------------
--
--  host table to keep track on what ip address was assigned with pinger 
-- hostname
--   ip_number has length of 64 - to accomodate possible IPv6 
--
CREATE TABLE host (
 ip_name varchar(52) NOT NULL, 
 ip_number varchar(64) NOT NULL,
 comments text, 
 PRIMARY KEY  (ip_name, ip_number) );


--
--     meta data table ( Period is an interval, since interval is reserved word )
--
CREATE TABLE  metaData  (
 metaID INTEGER PRIMARY KEY, 
 ip_name_src varchar(52) NOT NULL,
 ip_name_dst varchar(52) NOT NULL,
 transport varchar(10)  NOT NULL,
 packetSize smallint   NOT NULL,
 count smallint   NOT NULL,
 packetInterval smallint,
 deadline smallint,
 ttl smallint,
 -- INDEX (ip_name_src, ip_name_dst, packetSize, count),
 FOREIGN KEY (ip_name_src) references host (ip_name),
 FOREIGN KEY (ip_name_dst) references host (ip_name));

CREATE INDEX metaData_idx1 
  ON metaData (ip_name_src, ip_name_dst, packetSize, count);

CREATE TRIGGER metaData_fki
  BEFORE INSERT ON metaData FOR EACH ROW 
  BEGIN
    SELECT RAISE(ROLLBACK, 'Insert on metaData violates foreign key on ip_name_src')
      WHERE (SELECT ip_name FROM host WHERE ip_name = NEW.ip_name_src)
        IS NULL;
    SELECT RAISE(ROLLBACK, 'Insert on metaData violates foreign key on ip_name_dst')
      WHERE (SELECT ip_name FROM host WHERE ip_name = NEW.ip_name_dst)
        IS NULL;
  END;

CREATE TRIGGER metaData_fku 
  BEFORE UPDATE ON metaData FOR EACH ROW 
  BEGIN
    SELECT RAISE(ROLLBACK, 'Update on metaData violates foreign key on ip_name_src')
      WHERE (SELECT ip_name FROM host WHERE ip_name = NEW.ip_name_src)
        IS NULL;
    SELECT RAISE(ROLLBACK, 'Update on metaData violates foreign key on ip_name_dst')
      WHERE (SELECT ip_name FROM host WHERE ip_name = NEW.ip_name_dst)
        IS NULL;
  END;

-- Prevent deletion of host records in use by metaData
CREATE TRIGGER host_fkd
  BEFORE DELETE ON host FOR EACH ROW
  BEGIN
    SELECT RAISE(ROLLBACK, 'Delete from host violates foreign key from metaData.ip_name_src')
      WHERE (SELECT ip_name_src FROM metaData WHERE ip_name_src = OLD.ip_name) IS NOT NULL;
    SELECT RAISE(ROLLBACK, 'Delete from host violates foreign key from metaData.ip_name_dst')
      WHERE (SELECT ip_name_dst FROM metaData WHERE ip_name_dst = OLD.ip_name) IS NOT NULL;
  END;

--   pinger data table, some fields have names differnt from XML schema since there where
--   inherited from the current pinger data table
--   its named data_yyyyMM to separate from old format - pairs_yyyyMM
--
CREATE TABLE  data  (
  metaID   INTEGER,
  minRtt float,
  meanRtt float,
  medianRtt float,
  maxRtt float,
  timestamp bigint(12) NOT NULL,
  minIpd float,
  meanIpd float,
  maxIpd float,
  duplicates tinyint(1),
  outOfOrder  tinyint(1),
  clp float,
  iqrIpd float,
  lossPercent  float,
  rtts text, -- should be stored as csv of ping rtts
  seqNums text, -- should be stored as csv of ping sequence numbers
  -- INDEX (meanRtt, medianRtt, lossPercent, meanIpd, clp),
  FOREIGN KEY (metaID) references metaData (metaID),
  PRIMARY KEY  (metaID, timestamp));

CREATE INDEX data_idx1 
  ON data (meanRtt,medianRtt, lossPercent, meanIpd, clp);
