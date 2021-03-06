/* Copyright 2011 Blue River Interactive

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
component extends="mura.plugin.pluginGenericEventHandler" {

	function onApplicationLoad($){
		variables.pluginConfig.addEventHandler(this);
	}

	function login($){
		var rsGroups = "";
		var userStruct = "";
		var userBean = "";
		var rsMemberships = "";
		var rolelist="";
		var adminGroup=variables.pluginConfig.getSetting('AdminGroup');
		var i="";
		var tempPassword = createUUID();
		var siteID= $.event("siteID");
		var mode = $.event("externalLoginMode");
		var settingsManager = "";
		var currRow=0;
			
		if(not len(siteID)){
			if(len(variables.pluginConfig.getSetting('defaultSiteID'))){
				siteID=variables.pluginConfig.getSetting('defaultSiteID');
			} else {
				siteID=getSiteID();
			}
			$.event('siteID',siteID);
		}
		
		userStruct=lookUpUser($.event("username"),$.event("password"),$.event("externalLoginMode"));
		
		if(userStruct.found){
						            
			if(len(userStruct.memberships) and variables.pluginConfig.getSetting('syncMemberships') eq "True"){		
				rsGroups=application.userManager.getPublicGroups($.event('siteID'));     
				
				currRow=1; 
			     do { 
			       	if(listFindNoCase(userStruct.memberships,rsGroups[currRow].groupname){
						rolelist=listappend(rolelist,rsGroups[currRow].userID);
					}
			       currRow=currRow+1; 
			     } while (currRow LTE rsGroups.RecordCount); 

		        rsGroups=application.userManager.getPrivateGroups($.event('siteID'));     
				
				currRow=1; 
			     do { 
			     	if(rsGroups.groupname eq "Admin"){
				     	if(listFindNoCase(userStruct.memberships,adminGroup)){
				     		rolelist=listappend(rolelist,rsGroups[currRow].userID);
				     	}
				    } else {
				       	if(listFindNoCase(userStruct.memberships,rsGroups[currRow].groupname){
							rolelist=listappend(rolelist,rsGroups[currRow].userID);
						}
					}
			       currRow=currRow+1; 
			     } while (currRow LTE rsGroups.RecordCount); 
			}
			
			lock 
				name="#$.event('siteID')##userStruct.username#userBridge" 
				timeout="30" 
				type="exclusive"{
				
				//check to see if the user has previous login into the system
				userBean=$.getBean('user').loadBy(username=userStruct.username,siteID=$.event('siteID'));						
							
				userBean.set(userStruct);
				userBean.setPassword(tempPassword);
				userBean.setlastUpdateBy('System');
							
				if(variables.pluginConfig.getSetting('syncMemberships') eq "True"){				
					userBean.setGroupID(rolelist);
				}
								
				if(len(variables.pluginConfig.getSetting('groupID'))){
					userBean.setGroupID(variables.pluginConfig.getSetting('groupID'),true);
				}
							
				if(userBean.getIsNew()){
					if(variables.pluginConfig.getSetting('isPublic') eq "0"){
						userBean.setSiteID($.siteConfig('PrivateUserPoolID'));
						userBean.setIsPublic(0);
					} else {
						userBean.setSiteID($.siteConfig('PublicUserPoolID'));
						userBean.setIsPublic(1);
					}
				}
							
				userBean.save();				
			}

			$.event("username",userStruct.username);
			$.event("password",tempPassword);
			
			//log the user in
			if(mode eq "auto"){			
				getBean("userUtility").loginByUserID(userBean.getUserID(),siteID);			
				//set siteArray
				if(session.mura.isLoggedIn and not structKeyExists(session,"siteArray") or ArrayLen(session.siteArray) eq 0){
					session.siteArray=arrayNew(1);
					settingsManager = getBean("settingsManager");
					for( site in settingsManager.getSites()) {
						if(application.permUtility.getModulePerm("00000000000000000000000000000000000","#site#")){
							arrayAppend(session.siteArray,site);
						}
					}
				}			
			}
				
		}
				
	}

	function lookupUser(username,password){

		var returnStruct={};

		//Do you custom logic to look up use in external user database.
		//Set the "returnStruct .success" variables. to true or false depending if the user was found.
		if(arguments.username eq "John"){
			
			//The memberships attribute is a comma separated list of user groups or roles that this user  should be assigned (IE. "Sales,Member,Board of Directors")
			returnStruct{
					found=true,
					fname= "John",
					lname= "Doe",
					username= "JohnDoe",
					remoteID= "JohnDoe",
					email= "john@example.com",
					memberships=""
				}
		} else {	

			returnStruct={
					found=false,
					fname= "",
					lname= "",
					username= "",
					email= "",
					memberships=""
				}
		}

		return returnStruct;
	}



	function getSiteID(){
			var siteID="";
			var rsSites=application.settingsManager.getList(sortBy="orderno");
			var currRow=1;
			
			//check for exact host match to find siteID
			do { 
			      	try{
						if(cgi.SERVER_NAME eq application.settingsManager.getSite(rsSites[currRow].siteID).getDomain()){
							siteID = rsSites[currRow].siteID;
							break;
						}
					}
					catch{}
					
			       	currRow=currRow+1; 
			    } while (currRow LTE rsSites.RecordCount); 

			if(not len(siteID)){
				do { 
			      	try{
						if(find(cgi.SERVER_NAME,application.settingsManager.getSite(rsSites{currRow].siteID).getDomain())){
							siteID = rsSites[currRow].siteID;
							break;
						}
					}
					catch{}
					
			       	currRow=currRow+1; 
			    } while (currRow LTE rsSites.RecordCount); 
			}
			
			if(not len(siteID)){
				siteID = rsSites.siteID;
			}		
			
			return siteid;
	}

	function onSiteRequestStart($){
		var username="";
		
		if(variables.pluginConfig.getSetting('mode') eq "Automatic" 
			and variables.pluginConfig.getSetting('where') eq 'Site'
			and not $.currentUser().getIsLoggedIn()
			and len(variables.pluginConfig.getSetting('AutoLoginCurrentUser'))){
			
			try{
				username=evaluate(variables.pluginConfig.getSetting('AutoLoginCurrentUser'));
			} catch {}
			
			if(len(username)){
				$.event("username",username);	
				$.event("externalLoginMode","auto");	
				login($);
			}			
		}
	}

	function onGlobalRequestStart($){
		var username="";
		
		if(variables.pluginConfig.getSetting('mode') eq "Automatic" 
			and variables.pluginConfig.getSetting('where') eq 'Global'
			and not $.currentUser().getIsLoggedIn()
			and len(variables.pluginConfig.getSetting('AutoLoginCurrentUser'))){
			
			try{
				username=evaluate(variables.pluginConfig.getSetting('AutoLoginCurrentUser'));
			} catch{}
			
			if(len(username)){
				$.event("username",username);	
				$.event("externalLoginMode","auto");	
				login($);
			}		
		} 
	}

	function onSiteLogin($){
		var mode=variables.pluginConfig.getSetting('mode');
		if(mode eq "Manual" or not len(mode)){
			$.event("externalLoginMode","manual");
			login($);
		}
	}

	function onGlobalLogin($){
		var mode=variables.pluginConfig.getSetting('mode');
		if(
			(mode eq "Manual" or not len(mode)){
			and variables.pluginConfig.getSetting('where') eq "global"){
			$.event("externalLoginMode","manual");
			login($);
		}  
	}

}