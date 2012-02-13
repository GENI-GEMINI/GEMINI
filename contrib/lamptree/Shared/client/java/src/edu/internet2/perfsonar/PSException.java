package edu.internet2.perfsonar;

/**
 * General exception class for errors thrown by perfSONAR
 */
public class PSException extends Exception{
	public PSException(String msg){
		super(msg);
	}
	
	public PSException(Exception e){
		super(e);
	}
}
