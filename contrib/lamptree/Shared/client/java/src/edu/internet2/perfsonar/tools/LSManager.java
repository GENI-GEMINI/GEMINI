package edu.internet2.perfsonar.tools;

import java.awt.Container;
import java.awt.FlowLayout;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.net.InetAddress;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Properties;

import javax.swing.*;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;

import org.apache.commons.httpclient.HttpException;
import org.jdom.Element;

import edu.internet2.perfsonar.NodeRegistration;
import edu.internet2.perfsonar.PSException;
import edu.internet2.perfsonar.ServiceRegistration;
import edu.internet2.perfsonar.dcn.DCNLookupClient;


public class LSManager extends JFrame{
	private static final long serialVersionUID = 1L;
	private static LSManager instance;
	private String hintsFile;
	private String[] glsList;
	private String[] hlsList;
	private boolean bootstrap;
	
	//Registration Tab Values
	private String[] fieldTypes = {"Service Type", "Name","Description", "Runs On",
			   					   "URLs", "Controls", "Subscribers", 
			   					   "Publishers", "Protocol", "Topics"};
	private String[][] topics = {{"idc:INFO",""}, {"idc:IDC",""}, {"idc:DEBUG",""}, {"idc:ERROR",""}};
	private HashMap<String,Container> regFields;
	private JList protoList;
	private HashMap<String,Boolean> textAreas;
	private HashMap<String,String[]> combos;
	private  HashMap<String,String[]> lists;
	private HashMap<String,String[][]> msgs;
	private HashMap<String,JScrollPane> msgPanels;
	
	synchronized public static LSManager getInstance(){
		if(LSManager.instance == null){
			LSManager.instance = new LSManager();
		}
		return LSManager.instance;
	}
	
	public LSManager(){
		super("perfSONAR Lookup Service Manager");
		this.loadConstants();
		this.regFields = new HashMap<String,Container>();
		this.getContentPane().setLayout(null);
		JPanel regPanel = this.createRegPanel();
		JPanel lookupPanel = this.createLookupPlanel();
		JPanel settingsPanel = this.createSettingsPanel();
		
		JTabbedPane tabbedPane = new JTabbedPane();
		tabbedPane.setBounds(10, 10, 680, 560);
		tabbedPane.addTab("Register", regPanel);
		tabbedPane.addTab("Lookup", lookupPanel);
		tabbedPane.addTab("Settings", settingsPanel);
		this.getContentPane().add(tabbedPane);
		
		/* Set window properties */
		this.pack();
		this.setSize(700, 600);
		this.setVisible(true);
	}
	
	private JPanel createRegPanel() {
		final int REG_LBL_WIDTH=95;
		final int REG_LBL_HEIGHT=25;
		final int REG_FIELD_WIDTH=500;
		final int REG_FIELD_HEIGHT=25;
		final int REG_MARGIN=10;
		final int REG_PAD=5;
		
		JPanel panel = new JPanel();
		int y = 0;
		panel.setLayout(null);
		panel.setBounds(10,10, REG_FIELD_WIDTH+REG_LBL_WIDTH+REG_PAD+REG_MARGIN*2, 1000);

		for(String field : fieldTypes){
			JLabel lbl = new JLabel(field + ":");
			Container cmpnt = null;
			if(textAreas.containsKey(field)){
				cmpnt = new JTextArea();
				((JComponent) cmpnt).setBorder((new JTextField()).getBorder());
				cmpnt.setBounds(REG_MARGIN + REG_LBL_WIDTH+REG_PAD, y, REG_FIELD_WIDTH, REG_FIELD_HEIGHT*2);
				lbl.setBounds(REG_MARGIN, y, REG_LBL_WIDTH, REG_LBL_HEIGHT);
				y += REG_FIELD_HEIGHT*2 + REG_PAD;
			}else if(combos.containsKey(field)){
				cmpnt = new JComboBox(combos.get(field));
				((JComboBox) cmpnt).setEditable(true);
				cmpnt.setBounds(REG_MARGIN + REG_LBL_WIDTH+REG_PAD, y, REG_FIELD_WIDTH, REG_FIELD_HEIGHT);
				lbl.setBounds(REG_MARGIN, y, REG_LBL_WIDTH, REG_LBL_HEIGHT);
				y += REG_FIELD_HEIGHT + REG_PAD;
			}else if(lists.containsKey(field)){
				cmpnt = new JPanel();
				cmpnt.setLayout(null);
				
				for(String proto : lists.get(field)){
					JPanel msgPane = new JPanel(); 
					msgPane.setLayout(new BoxLayout(msgPane, BoxLayout.Y_AXIS));
					int i = 0;
					for(String[] msg: msgs.get(proto)){
						final int index = i;
						final String p = proto;
						JCheckBox check = new JCheckBox(msg[0]);
						check.addItemListener(new ItemListener(){
							public void itemStateChanged(ItemEvent e) {
								String[][] msgInfo =LSManager.getInstance().getMsgs().get(p);
								msgInfo[index][1] = (e.getStateChange() == ItemEvent.SELECTED ? "1" : "");
							}
						});
						msgPane.add(check);
						i++;
					}
					JScrollPane msgScrollPane = new JScrollPane(msgPane);
					msgScrollPane.setVisible(false);
					msgScrollPane.setBounds((int)(.6*REG_FIELD_WIDTH), 0, (int)(.4*REG_FIELD_WIDTH), REG_FIELD_HEIGHT*3);
					this.msgPanels.put(proto,msgScrollPane);
					cmpnt.add(msgScrollPane);
				}
				
				this.protoList = new JList(lists.get(field));
				protoList.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
				JScrollPane protoScrollPane = new JScrollPane(protoList);
				protoScrollPane.setBounds(0, 0, (int)(.6*REG_FIELD_WIDTH) - 2*REG_PAD, REG_FIELD_HEIGHT*3);
				this.protoList.addListSelectionListener(new ListSelectionListener(){
					public void valueChanged(ListSelectionEvent e) {
						LSManager.updateMsgPane();
					}
				});
				cmpnt.add(protoScrollPane);
				
				cmpnt.setBounds(REG_MARGIN + REG_LBL_WIDTH+REG_PAD, y, REG_FIELD_WIDTH, REG_FIELD_HEIGHT*3);
				lbl.setBounds(REG_MARGIN, y, REG_LBL_WIDTH, REG_LBL_HEIGHT);
				y += REG_FIELD_HEIGHT*3 + REG_PAD;
			}else if("Topics".equals(field)){
				cmpnt = new JPanel();
				cmpnt.setLayout(new FlowLayout(FlowLayout.LEFT));
				for(String[] topic : this.topics){
					final String[] t = topic;
					JCheckBox check = new JCheckBox(t[0]);
					check.addItemListener(new ItemListener(){
						public void itemStateChanged(ItemEvent e) {
							t[1] = (e.getStateChange() == ItemEvent.SELECTED ? "1" : "");
						}
					});
					cmpnt.add(check);
				}
				cmpnt.setBounds(REG_MARGIN + REG_LBL_WIDTH+REG_PAD, y, REG_FIELD_WIDTH, REG_FIELD_HEIGHT);
				lbl.setBounds(REG_MARGIN, y, REG_LBL_WIDTH, REG_LBL_HEIGHT);
				y += REG_FIELD_HEIGHT + REG_PAD;
			}else{
				cmpnt = new JTextField();
				cmpnt.setBounds(REG_MARGIN + REG_LBL_WIDTH+REG_PAD, y, REG_FIELD_WIDTH, REG_FIELD_HEIGHT);
				lbl.setBounds(REG_MARGIN, y, REG_LBL_WIDTH, REG_LBL_HEIGHT);
				y += REG_PAD+REG_FIELD_HEIGHT;
			}
			panel.add(lbl);
			panel.add(cmpnt);
			regFields.put(field, cmpnt);
		}
		JButton regButton = new JButton("Register");
		regButton.setBounds(panel.getWidth()-REG_MARGIN-100, y, 100, 20);
		regButton.addMouseListener(new MouseAdapter(){
			public void mousePressed(MouseEvent e){
				LSManager.registerService();
			}
		});
		panel.add(regButton);
		return panel;
	}
	
	public static void updateMsgPane(){
		LSManager mgr = LSManager.getInstance();
		JList protoList = mgr.getProtoList();
		HashMap<String,JScrollPane> msgPanels = mgr.getMsgPanels();
		for(String proto : msgPanels.keySet()){
			msgPanels.get(proto).setVisible(false);
		}
		if(msgPanels.containsKey(protoList.getSelectedValue())){
			msgPanels.get(protoList.getSelectedValue()).setVisible(true);
			msgPanels.get(protoList.getSelectedValue()).repaint();
		}
	}
	
	public static void registerService(){
		final String ERR_TYPE = "Registartion Error";
		LSManager mgr = LSManager.getInstance();
		String name = ((JTextField)mgr.getRegFields().get("Name")).getText();
		if(name == null || "".equals(name.trim())){
			mgr.reportError(ERR_TYPE, "Please fill-in the 'Name' Field");
			return;
		}
		String type = (String)((JComboBox)mgr.getRegFields().get("Service Type")).getSelectedItem();
		if(type == null || "".equals(type.trim())){
			mgr.reportError(ERR_TYPE, "Please select a 'Service Type'");
			return;
		}
		ServiceRegistration reg = new ServiceRegistration(name.trim(), type.trim());
		
		String description = ((JTextField)mgr.getRegFields().get("Description")).getText();
		if(description != null && (!"".equals(description.trim()))){
			reg.setDescription(description.trim());
		}
		String node = ((JTextField)mgr.getRegFields().get("Runs On")).getText();
		if(node != null && (!"".equals(node.trim()))){
			node = node.trim();
			if(!node.matches("urn:ogf:network:domain=.+:node=.+")){
				mgr.reportError(ERR_TYPE, "The 'Runs On' field must be a node URN");
				return;
			}
			reg.setNode(node);
		}else{
			mgr.reportError(ERR_TYPE, "Please fill-in the 'Runs On' field");
			return;
		}
		String urlStr = ((JTextArea)mgr.getRegFields().get("URLs")).getText();
		if(urlStr == null || "".equals(urlStr.trim())){
			mgr.reportError(ERR_TYPE, "Please specify at least one URL");
			return;
		}
		String[] urls = urlStr.split("\n");
		for(String url : urls){
			try{ 
				new URL(url);
			}catch(Exception e){
				mgr.reportError(ERR_TYPE, "Invalid URL specified: " + url); 
				return;
			}
		}
		
		String ctrlStr = ((JTextArea)mgr.getRegFields().get("Controls")).getText();
		if(ctrlStr != null && (!"".equals(ctrlStr.trim()))){
			String[] domains = ctrlStr.split("\n");
			for(String domain : domains){
				if(!domain.matches("urn:ogf:network:domain=.+")){
					mgr.reportError(ERR_TYPE, "Invalid domain URN specified for 'Controls': " + domain); 
					return;
				}
			}
			reg.setControls(domains);
		}
		
		String subscrStr = ((JTextArea)mgr.getRegFields().get("Subscribers")).getText();
		if(subscrStr != null && (!"".equals(subscrStr.trim()))){
			String[] subscribers = subscrStr.split("\n");
			reg.setSubscriberRel(subscribers);
		}
		
		String pubStr = ((JTextArea)mgr.getRegFields().get("Publishers")).getText();
		if(pubStr != null && (!"".equals(pubStr.trim()))){
			String[] publishers = pubStr.split("\n");
			reg.setPublisherRel(publishers);
		}
		
		for(String proto : mgr.getMsgs().keySet()){
			String[][] msgInfos = mgr.getMsgs().get(proto);
			ArrayList<String> implMsgs = new ArrayList<String>();
			for(String[] msgInfo : msgInfos){
				if(msgInfo[1] != null && "1".equals(msgInfo[1])){
					implMsgs.add(msgInfo[0]);
				}
			}
			if(!implMsgs.isEmpty()){
				HashMap<String,String[]> params = new HashMap<String,String[]>();
				params.put(DCNLookupClient.PARAM_SUPPORTED_MSG, implMsgs.toArray(new String[implMsgs.size()]));
				reg.setPort(urls, proto, params);
			}
		}
		
		ArrayList<String> implTopics = new ArrayList<String>();
		for(String[] topic : mgr.getTopics()){
			if(topic[1] != null && "1".equals(topic[1])){
				implTopics.add(topic[0]);
			}
		}
		if(!implTopics.isEmpty()){
			HashMap<String, String[]> topicMap = new HashMap<String, String[]>();
			topicMap.put(DCNLookupClient.PARAM_TOPIC, implTopics.toArray(new String[implTopics.size()]));
			reg.setOptionalParameters(topicMap);
		}
		
		NodeRegistration nodeReg = new NodeRegistration(node);
		for(String urlString : urls){
			try{
				URL url = new URL(urlString);
				InetAddress ip = InetAddress.getByName(url.getHost());
				nodeReg.setName(url.getHost(), "dns");
				nodeReg.setL3Address(ip.getHostAddress(), false);
			}catch(Exception e){}
		}

		
		DCNLookupClient lsClient = null;
		if(mgr.getHintsFile() == null){
			lsClient = new DCNLookupClient(mgr.getGlsList(), mgr.getHlsList());
		}else{
			try {
				lsClient = new DCNLookupClient(mgr.getHintsFile(), mgr.getHlsList());
			} catch (Exception e){
				mgr.reportError(ERR_TYPE, e.getMessage());
			}
		}
		try {
			Element nodeElem = lsClient.lookupNode(new URL(urls[0]).getHost());
			if(nodeElem == null){
				lsClient.registerNode(nodeReg);
			}
			lsClient.registerService(reg);
		} catch (PSException e) {
			mgr.reportError(ERR_TYPE, "Error returned from LS: " + e.getMessage());
		} catch (MalformedURLException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		System.out.println(reg);
	}
	
	public void reportError(String type, String msg){
		JOptionPane.showMessageDialog(this, msg, type, JOptionPane.ERROR_MESSAGE);
	}
	
	private void loadConstants(){
		this.textAreas = new HashMap<String, Boolean>();
		this.textAreas.put("URLs", true);
		this.textAreas.put("Controls", true);
		this.textAreas.put("Subscribers", true);
		this.textAreas.put("Publishers", true);
		
		this.combos = new HashMap<String, String[]>();
		String[] cbChoices = {"IDC", "NotificationBroker"};
		this.combos.put("Service Type", cbChoices);
		
		this.lists = new HashMap<String, String[]>();
		String[] tmpArr = {"http://oscars.es.net/OSCARS", "http://docs.oasis-open.org/wsn/b-2", "http://docs.oasis-open.org/wsn/br-2"};
		this.msgs = new HashMap<String, String[][]>();
		this.lists.put("Protocol", tmpArr);
		String[][] tmpArr2 = {{"createReservation",""}, {"modifyReservation",""},
							  {"cancelReservation",""}, {"createPath",""}, 
							  {"refreshPath",""}, {"teardownPath",""}, 
							  {"queryReservation",""}, {"listReservation",""},
							  {"getNetworkTopology",""}};
		this.msgs.put(tmpArr[0], tmpArr2);
		String[][] tmpArr3 = {{"Notify",""}, {"Subscribe",""}, {"Renew",""}, {"Unsubscribe",""}, {"PauseSubscription",""}, {"ResumeSubscription",""}};
		this.msgs.put(tmpArr[1], tmpArr3);
		String[][] tmpArr4 = {{"RegisterPublisher", ""}, {"DestroyRegistration",""}};
		this.msgs.put(tmpArr[2], tmpArr4);
		this.msgPanels = new HashMap<String,JScrollPane>();
		
		Properties props = new Properties();
		File propsFile = new File("conf/ps.properties");
		try {
			props.load(new FileInputStream(propsFile));
		} catch (FileNotFoundException e) {
			this.reportError("Configuration Error", e.getMessage());
		} catch (IOException e) {
			this.reportError("Configuration Error", e.getMessage());
		}
		this.hintsFile = props.getProperty("hintsFile");
		if(props.getProperty("gls") != null){
			this.glsList = props.getProperty("gls").split(",");
		}
		if(props.getProperty("hls") != null){
			this.hlsList = props.getProperty("hls").split(",");
		}
		if(props.getProperty("bootstrap") != null){
			this.bootstrap = "1".equals(props.getProperty("bootstrap"));
		}
	}
	
	public JPanel createSettingsPanel(){
		final int SET_RADIO_WIDTH=100;
		final int SET_RADIO_HEIGHT=20;
		final int SET_TEXT_WIDTH=500;
		final int SET_TEXT_HEIGHT=20;
		final int SET_MARGIN=10;
		final int SET_PAD=5;
		
		JPanel panel = new JPanel();
		panel.setLayout(null);
		
		ButtonGroup buttonGroup = new ButtonGroup();
		JRadioButton hintsRadio = new JRadioButton("Hints file:");
		JRadioButton glsRadio = new JRadioButton("Global LS:");
		hintsRadio.setSelected(this.bootstrap);
		glsRadio.setSelected(!this.bootstrap);
		
		buttonGroup.add(hintsRadio);
		buttonGroup.add(glsRadio);
		
		final JTextField hintsField = new JTextField();
		final JTextArea glsTextArea = new JTextArea();
		final JTextArea hlsTextArea = new JTextArea();
		JLabel hlsLabel = new JLabel("Home LS: ");
		JButton saveButton = new JButton("Save");
		glsTextArea.setEnabled(!this.bootstrap);
		hintsField.setEnabled(this.bootstrap);
		if(this.hintsFile != null){
			hintsField.setText(this.hintsFile);
		}
		if(this.glsList != null){
			String glsText = "";
			int lines = 0;
			for(String gls : this.glsList){
				if(lines > 0){ glsText += "\n"; }
				glsText += gls;
				lines++;
			}
			glsTextArea.setText(glsText);
		}
		if(this.hlsList != null){
			String hlsText = "";
			int lines = 0;
			for(String hls : this.hlsList){
				if(lines > 0){ hlsText += "\n"; }
				hlsText += hls;
				lines++;
			}
			hlsTextArea.setText(hlsText);
		}
		hintsRadio.addItemListener(new ItemListener(){
			public void itemStateChanged(ItemEvent e) {
				if(e.getStateChange() == ItemEvent.SELECTED){
					glsTextArea.setEnabled(false);
					hintsField.setEnabled(true);
				}else{
					glsTextArea.setEnabled(true);
					hintsField.setEnabled(false);
				}
			}
		});
		saveButton.addMouseListener(new MouseAdapter(){
			public void mousePressed(MouseEvent e){
				LSManager.saveSettings(hintsField.getText(), glsTextArea.getText(), hlsTextArea.getText(), hintsField.isEnabled());
			}
		});
		hintsField.setBounds(SET_MARGIN+SET_RADIO_WIDTH+SET_PAD,SET_MARGIN,SET_TEXT_WIDTH,SET_TEXT_HEIGHT);
		hintsRadio.setBounds(SET_MARGIN,SET_MARGIN, SET_RADIO_WIDTH,SET_RADIO_HEIGHT);
		glsTextArea.setBounds(SET_MARGIN+SET_RADIO_WIDTH+SET_PAD,SET_MARGIN+SET_RADIO_HEIGHT+SET_PAD,SET_TEXT_WIDTH,SET_TEXT_HEIGHT*3);
		glsTextArea.setBorder(hintsField.getBorder());
		glsRadio.setBounds(SET_MARGIN,SET_MARGIN+SET_RADIO_HEIGHT+SET_PAD, SET_RADIO_WIDTH,SET_RADIO_HEIGHT);
		hlsTextArea.setBorder(hintsField.getBorder());
		hlsTextArea.setBounds(SET_MARGIN+SET_RADIO_WIDTH+SET_PAD,SET_MARGIN+SET_RADIO_HEIGHT*4+SET_PAD*6,SET_TEXT_WIDTH,SET_TEXT_HEIGHT*3);
		hlsLabel.setBounds(SET_MARGIN,SET_MARGIN+SET_RADIO_HEIGHT*4+SET_PAD*6, SET_RADIO_WIDTH,SET_RADIO_HEIGHT);
		saveButton.setBounds(SET_MARGIN+SET_PAD+SET_RADIO_WIDTH+SET_TEXT_WIDTH-100,SET_MARGIN+SET_RADIO_HEIGHT*7+SET_PAD*7, 100,20);
		panel.add(hintsRadio);
		panel.add(glsRadio);
		panel.add(hintsField);
		panel.add(hlsTextArea);
		panel.add(hlsLabel);
		panel.add(glsTextArea);
		panel.add(saveButton);
		return panel;
	}
	
	protected static void saveSettings(String hintsFile, String gls, String hls, boolean useHints) {
		final String ERR_TYPE = "Confiuration Error";
		LSManager mgr = LSManager.getInstance();
		if(useHints && hintsFile != null && (!"".equals(hintsFile.trim()))){
			try{
				new URL(hintsFile);
			}catch(Exception e){
				mgr.reportError(ERR_TYPE,"Hints file must be a URL");
				return;
			}
			mgr.setGlsList(null);
			mgr.setHintsFile(hintsFile);
		}else if(gls != null && (!"".equals(gls.trim()))){
			String[] glsList = gls.split("\n");
			for(String glsUrl : glsList){
				try{
					new URL(glsUrl);
				}catch(Exception e){
					mgr.reportError(ERR_TYPE,"Global LS list contains invalid URL: " + glsUrl);
					return;
				}
			}
			mgr.setGlsList(glsList);
			mgr.setHintsFile(null);
		}else{
			mgr.reportError(ERR_TYPE,"Please specify a hints file or Global LS");
			return;
		}
		
		if(hls != null && (!"".equals(hls.trim()))){
			String[] hlsList = hls.split("\n");
			for(String hlsUrl : hlsList){
				try{
					new URL(hlsUrl);
				}catch(Exception e){
					mgr.reportError(ERR_TYPE,"Home LS list contains invalid URL: " + hlsUrl);
					return;
				}
			}
			mgr.setHlsList(hlsList);
		}else{
			mgr.reportError(ERR_TYPE,"Please specify a Home LS");
			return;
		}
	}
	
	public JPanel createLookupPlanel(){
		JPanel panel = new JPanel();
		JLabel lbl1 = new JLabel("Lookup");
		JLabel lbl2 = new JLabel("that controls domain");
		String[] types = {"IDC", "NotifcationBroker", "Host", "Node", "Custom"};
		JComboBox type = new JComboBox(types);
		JTextArea query = new JTextArea();
		JTextArea response = new JTextArea();
		response.setEditable(false);
		JButton submitButton = new JButton("Lookup");
		
		/* Set Position */
		final int SET_TEXT_WIDTH=500;
		final int SET_TEXT_HEIGHT=20;
		final int SET_MARGIN=10;
		final int SET_PAD=5;
		
		panel.add(lbl1);
		panel.add(type);
		panel.add(lbl2);
		panel.add(query);
		panel.add(submitButton);
		panel.add(response);
		
		return panel;
	}
	
	/**
	 * @return the protoList
	 */
	public JList getProtoList() {
		return protoList;
	}
	/**
	 * @param protoList the protoList to set
	 */
	public void setProtoList(JList protoList) {
		this.protoList = protoList;
	}
	/**
	 * @return the regFields
	 */
	public HashMap<String, Container> getRegFields() {
		return regFields;
	}
	/**
	 * @param regFields the regFields to set
	 */
	public void setRegFields(HashMap<String, Container> regFields) {
		this.regFields = regFields;
	}
	
	public static void main(String[] args){
		LSManager frame = LSManager.getInstance();
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
	}

	/**
	 * @return the msgPanels
	 */
	public HashMap<String, JScrollPane> getMsgPanels() {
		return msgPanels;
	}

	/**
	 * @param msgPanels the msgPanels to set
	 */
	public void setMsgPanels(HashMap<String, JScrollPane> msgPanels) {
		this.msgPanels = msgPanels;
	}

	/**
	 * @return the msgs
	 */
	public HashMap<String, String[][]> getMsgs() {
		return msgs;
	}

	/**
	 * @param msgs the msgs to set
	 */
	public void setMsgs(HashMap<String, String[][]> msgs) {
		this.msgs = msgs;
	}

	/**
	 * @return the fieldTypes
	 */
	public String[] getFieldTypes() {
		return fieldTypes;
	}

	/**
	 * @param fieldTypes the fieldTypes to set
	 */
	public void setFieldTypes(String[] fieldTypes) {
		this.fieldTypes = fieldTypes;
	}

	/**
	 * @return the combos
	 */
	public HashMap<String, String[]> getCombos() {
		return combos;
	}

	/**
	 * @param combos the combos to set
	 */
	public void setCombos(HashMap<String, String[]> combos) {
		this.combos = combos;
	}

	/**
	 * @return the lists
	 */
	public HashMap<String, String[]> getLists() {
		return lists;
	}

	/**
	 * @param lists the lists to set
	 */
	public void setLists(HashMap<String, String[]> lists) {
		this.lists = lists;
	}

	/**
	 * @return the textAreas
	 */
	public HashMap<String, Boolean> getTextAreas() {
		return textAreas;
	}

	/**
	 * @param textAreas the textAreas to set
	 */
	public void setTextAreas(HashMap<String, Boolean> textAreas) {
		this.textAreas = textAreas;
	}

	/**
	 * @return the topics
	 */
	public String[][] getTopics() {
		return topics;
	}

	/**
	 * @param topics the topics to set
	 */
	public void setTopics(String[][] topics) {
		this.topics = topics;
	}

	/**
	 * @return the glsList
	 */
	public String[] getGlsList() {
		return glsList;
	}

	/**
	 * @param glsList the glsList to set
	 */
	public void setGlsList(String[] glsList) {
		this.glsList = glsList;
	}

	/**
	 * @return the hintsFile
	 */
	public String getHintsFile() {
		return hintsFile;
	}

	/**
	 * @param hintsFile the hintsFile to set
	 */
	public void setHintsFile(String hintsFile) {
		this.hintsFile = hintsFile;
	}

	/**
	 * @return the hlsList
	 */
	public String[] getHlsList() {
		return hlsList;
	}

	/**
	 * @param hlsList the hlsList to set
	 */
	public void setHlsList(String[] hlsList) {
		this.hlsList = hlsList;
	}

}
