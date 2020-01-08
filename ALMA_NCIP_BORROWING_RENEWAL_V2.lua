-- Alma NCIP Borrowing Renewal Server Addon, version 2.0 (January 6, 2020)
-- This Server Addon was developed by Bill Jones (SUNY Geneseo) and Tim Jackson (SUNY Libraries Shared Services)
-- The purpose of this Addon is to allow for NCIP Borrowing Renewals to Alma where a Barcode for an item has been used in a field (like ItemInfo5) and sent to Alma as the Barcode
-- If a field has been selected for use (in the Config of this Addon), and that field is not blank, this Addon will send that Barcode as the Identifier for the item to Alma for renewal
-- If a field has been selected for use (in the Config of this Addon), and that field is blank, this Addon will default to send the Transaction Number as the Identifier for the item to Alma for renewal
-- If a field has not been selected for use (in the Config of this Addon), this Addon will default to send the Transaction Number as the Identifier for the item to Alma for renewal

-- This Addon is based on the Alma NCIP Borrowing Renewal Addon created by Kurt Munson @ Northwestern University

local Settings = {};

Settings.NCIP_Responder_URL = GetSetting("NCIP_Responder_URL");
Settings.renewItem_from_uniqueAgency_value = GetSetting("renewItem_from_uniqueAgency_value");
Settings.ApplicationProfileType = GetSetting("ApplicationProfileType");
Settings.RenewItemSearchQueue = GetSetting("RenewItemSearchQueue");
Settings.RenewItemSuccessQueue = GetSetting("RenewItemSuccessQueue");
Settings.RenewItemFailQueue = GetSetting("RenewItemFailQueue");
Settings.FieldToUseForBarcode = GetSetting("FieldToUseForBarcode");

local isCurrentlyProcessing = false;
local client = nil;

-- Assembly Loading and Type Importation
luanet.load_assembly("System");
local Types = {};
Types["WebClient"] = luanet.import_type("System.Net.WebClient");
Types["StreamReader"] = luanet.import_type("System.IO.StreamReader");

function Init()
	LogDebug("Initializing Alma NCIP Borrowing Renewal Addon");
	RegisterSystemEventHandler("SystemTimerElapsed", "TimerElapsed");
end

function TimerElapsed(eventArgs)
	LogDebug("Processing Alma NCIP Borrowing Renewal Items");
	if not isCurrentlyProcessing then
		isCurrentlyProcessing = true;

		-- Process Items
		local success, err = pcall(ProcessItems);
		if not success then
			LogDebug("There was a fatal error processing the items.")
			OnError(err);
		end

		isCurrentlyProcessing = false;
	else
		LogDebug("Still processing Alma NCIP Borrowing Renewal Items");
	end
end

function ProcessItems()
	ProcessDataContexts("TransactionStatus", Settings.RenewItemSearchQueue, "HandleContextProcessing");
end

function HandleContextProcessing()
	local transactionNumber = GetFieldValue("Transaction", "TransactionNumber");
	local RequestType = GetFieldValue("Transaction", "RequestType");

	-- Need to call the RenewItem function passing in the TN. Need an IF statement to start it
	if RequestType == "Loan" then
	
	RenewItem()
	end

end

function RenewItem()
	LogDebug("Creating url");
	local user = GetFieldValue("Transaction", "Username");
	local transactionNumber = GetFieldValue("Transaction", "TransactionNumber");
	local transactionNumbertoSend = "";
	LogDebug("FieldToUseForBarcode value: " .. Settings.FieldToUseForBarcode);

	if Settings.FieldToUseForBarcode ~= "" then
		if GetFieldValue("Transaction", Settings.FieldToUseForBarcode) ~= "" then
			LogDebug("Attempting FieldToUseForBarcode Config Setting is not blank and FieldToUseForBarcode is not blank");
			transactionNumbertoSend = GetFieldValue("Transaction", Settings.FieldToUseForBarcode);
			local dr = tostring(GetFieldValue("Transaction", "DueDate"));			
			LogDebug(dr);
			local df = string.match(dr, "%d+\/%d+\/%d+");
			LogDebug(df);
			local mn, dy, yr = string.match(df, "(%d+)/(%d+)/(%d+)");
			local mnt = string.format("%02d",mn);
			LogDebug (mnt);
			local dya = string.format("%02d",dy);
			LogDebug(dya);
			local url = Settings.NCIP_Responder_URL;
			LogDebug(url);
			local body = [[<?xml version="1.0" encoding="ISO-8859-1"?>
			<NCIPMessage version="http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd" xmlns="http://www.niso.org/2008/ncip">
			<RenewItem>
			<InitiationHeader>
			<FromAgencyId>
			<AgencyId>]] .. Settings.renewItem_from_uniqueAgency_value .. [[</AgencyId>
			</FromAgencyId> 
			<ToAgencyId>
			<AgencyId>]] .. Settings.renewItem_from_uniqueAgency_value .. [[</AgencyId>
			</ToAgencyId>
			<ApplicationProfileType>]] .. Settings.ApplicationProfileType .. [[</ApplicationProfileType>
			</InitiationHeader>
			<UserId>
			<UserIdentifierValue>]] .. user .. [[</UserIdentifierValue>
			</UserId>
			<ItemId>
			<ItemIdentifierValue>]] .. transactionNumbertoSend .. [[</ItemIdentifierValue>
			</ItemId>
			<DesiredDateDue>]] .. yr .. '-' .. mnt .. '-' .. dya .. [[</DesiredDateDue>
			</RenewItem>
			</NCIPMessage>
			]];
			-- 'T23:59:00' .. might need in date above at end if error on that	
			LogDebug(body);
	
			LogDebug("Creating web client.");
			local webClient = Types["WebClient"]();
			webClient.Headers:Clear();
			webClient.Headers:Add("Content-Type", "text/xml; charset=UTF-8");
			LogDebug("Sending RenewItem message.");
			local responseString = webClient:UploadString(url, body);
			LogDebug(responseString);
	
			-- 3 possible responses 1) empty URL 2) problem 3) it worked If datedue value returned OK, else problem
			-- Need to do something with the response 	
	
			if string.find(responseString, "<ns1:DateDue>") then
				LogDebug("No Problems found in NCIP Response.")
				ExecuteCommand("Route", {transactionNumber, Settings.RenewItemSuccessQueue});
				ExecuteCommand("AddNote", {transactionNumber, "NCIP Response for RenewItem received successfully"});
				SaveDataSource("Transaction");
			else
				LogDebug("NCIP Error: ReRouting Transaction");
				ExecuteCommand("Route", {transactionNumber, Settings.RenewItemFailQueue});
				LogDebug("Adding Note to Transaction with NCIP Problem Error");
				ExecuteCommand("AddNote", {transactionNumber, responseString});
				SaveDataSource("Transaction");
			end	
		end
	end
	
	if Settings.FieldToUseForBarcode ~= "" then
		if GetFieldValue("Transaction", Settings.FieldToUseForBarcode) == "" then
			LogDebug("Attempting FieldToUseForBarcode Config Setting is not blank and FieldToUseForBarcode IS blank");	
			transactionNumbertoSend = GetFieldValue("Transaction", "TransactionNumber");
			local dr = tostring(GetFieldValue("Transaction", "DueDate"));
			LogDebug(dr);
			local df = string.match(dr, "%d+\/%d+\/%d+");
			LogDebug(df);
			local mn, dy, yr = string.match(df, "(%d+)/(%d+)/(%d+)");
			local mnt = string.format("%02d",mn);
			LogDebug (mnt);
			local dya = string.format("%02d",dy);
			LogDebug(dya);
			local url = Settings.NCIP_Responder_URL;
			LogDebug(url);
			local body = [[<?xml version="1.0" encoding="ISO-8859-1"?>
			<NCIPMessage version="http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd" xmlns="http://www.niso.org/2008/ncip">
			<RenewItem>
			<InitiationHeader>
			<FromAgencyId>
			<AgencyId>]] .. Settings.renewItem_from_uniqueAgency_value .. [[</AgencyId>
			</FromAgencyId> 
			<ToAgencyId>
			<AgencyId>]] .. Settings.renewItem_from_uniqueAgency_value .. [[</AgencyId>
			</ToAgencyId>
			<ApplicationProfileType>]] .. Settings.ApplicationProfileType .. [[</ApplicationProfileType>
			</InitiationHeader>
			<UserId>
			<UserIdentifierValue>]] .. user .. [[</UserIdentifierValue>
			</UserId>
			<ItemId>
			<ItemIdentifierValue>]] .. transactionNumbertoSend .. [[</ItemIdentifierValue>
			</ItemId>
			<DesiredDateDue>]] .. yr .. '-' .. mnt .. '-' .. dya .. [[</DesiredDateDue>
			</RenewItem>
			</NCIPMessage>
			]];
			-- 'T23:59:00' .. might need in date above at end if error on that	
			LogDebug(body);
	
			LogDebug("Creating web client.");
			local webClient = Types["WebClient"]();
			webClient.Headers:Clear();
			webClient.Headers:Add("Content-Type", "text/xml; charset=UTF-8");
			LogDebug("Sending RenewItem message.");
			local responseString = webClient:UploadString(url, body);
			LogDebug(responseString);
	
			-- 3 possible responses 1) empty URL 2) problem 3) it worked If datedue value returned OK, else problem
			-- Need to do something with the response 	
	
			if string.find(responseString, "<ns1:DateDue>") then
				LogDebug("No Problems found in NCIP Response.")
				ExecuteCommand("Route", {transactionNumber, Settings.RenewItemSuccessQueue});
				ExecuteCommand("AddNote", {transactionNumber, "NCIP Response for RenewItem received successfully"});
				SaveDataSource("Transaction");	
			else
				LogDebug("NCIP Error: ReRouting Transaction");
				ExecuteCommand("Route", {transactionNumber, Settings.RenewItemFailQueue});
				LogDebug("Adding Note to Transaction with NCIP Problem Error");
				ExecuteCommand("AddNote", {transactionNumber, responseString});
				SaveDataSource("Transaction");
			end
		end
	end
		
		
	if Settings.FieldToUseForBarcode == "" then
		LogDebug("Attempting FieldToUseForBarcode Config Setting IS blank");
		transactionNumbertoSend = GetFieldValue("Transaction", "TransactionNumber");	
		local dr = tostring(GetFieldValue("Transaction", "DueDate"));
		LogDebug(dr);
		local df = string.match(dr, "%d+\/%d+\/%d+");
		LogDebug(df);
		local mn, dy, yr = string.match(df, "(%d+)/(%d+)/(%d+)");
		local mnt = string.format("%02d",mn);
		LogDebug (mnt);
		local dya = string.format("%02d",dy);
		LogDebug(dya);
		local url = Settings.NCIP_Responder_URL;
		LogDebug(url);
		local body = [[<?xml version="1.0" encoding="ISO-8859-1"?>
		<NCIPMessage version="http://www.niso.org/schemas/ncip/v2_0/ncip_v2_0.xsd" xmlns="http://www.niso.org/2008/ncip">
		<RenewItem>
		<InitiationHeader>
		<FromAgencyId>
		<AgencyId>]] .. Settings.renewItem_from_uniqueAgency_value .. [[</AgencyId>
		</FromAgencyId> 
		<ToAgencyId>
		<AgencyId>]] .. Settings.renewItem_from_uniqueAgency_value .. [[</AgencyId>
		</ToAgencyId>
		<ApplicationProfileType>]] .. Settings.ApplicationProfileType .. [[</ApplicationProfileType>
		</InitiationHeader>
		<UserId>
		<UserIdentifierValue>]] .. user .. [[</UserIdentifierValue>
		</UserId>
		<ItemId>
		<ItemIdentifierValue>]] .. transactionNumbertoSend .. [[</ItemIdentifierValue>
		</ItemId>
		<DesiredDateDue>]] .. yr .. '-' .. mnt .. '-' .. dya .. [[</DesiredDateDue>
		</RenewItem>
		</NCIPMessage>
		]];
		-- 'T23:59:00' .. might need in date above at end if error on that	
		LogDebug(body);
		LogDebug("Creating web client.");
		local webClient = Types["WebClient"]();
		webClient.Headers:Clear();
		webClient.Headers:Add("Content-Type", "text/xml; charset=UTF-8");
		LogDebug("Sending RenewItem message.");
		local responseString = webClient:UploadString(url, body);
		LogDebug(responseString);
	
		-- 3 possible responses 1) empty URL 2) problem 3) it worked If datedue value returned OK, else problem
		-- Need to do something with the response 	
	
		if string.find(responseString, "<ns1:DateDue>") then
			LogDebug("No Problems found in NCIP Response.")
			ExecuteCommand("Route", {transactionNumber, Settings.RenewItemSuccessQueue});
			ExecuteCommand("AddNote", {transactionNumber, "NCIP Response for RenewItem received successfully"});
			SaveDataSource("Transaction");	
		else
			LogDebug("NCIP Error: ReRouting Transaction");
			ExecuteCommand("Route", {transactionNumber, Settings.RenewItemFailQueue});
			LogDebug("Adding Note to Transaction with NCIP Problem Error");
			ExecuteCommand("AddNote", {transactionNumber, responseString});
			SaveDataSource("Transaction");
		end
	end	
end
