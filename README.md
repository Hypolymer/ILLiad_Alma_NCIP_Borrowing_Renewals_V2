# ILLiad Alma NCIP Borrowing Renewals V2

Hello and Welcome!

This is the official GitHub repository containing the latest updates for the ILLiad Alma NCIP  NCIP Borrowing Renewals V2 Server Addon.   The latest version of this Addon submitted to Atlas Systems can be found at the [ILLiad Addons Directory](https://atlas-sys.atlassian.net/wiki/spaces/ILLiadAddons/pages/3149601/ILLiad+Alma+NCIP+Borrowing+Renewal+Server+Addon).  

This is a Server Addon for ILLiad allowing for renewals from ILLiad to Alma via NCIP using a selectable ILLiad field as the barcode of an item.  If a field for a barcode is not set in the configuration, or if the ILLiad field selected for the barcode is blank, the Addon will send the Transaction Number by default.

This Server Addon needs to be installed in the Customization Manager as a .zip folder. Configurations for the Addon also happen in the Customization Manager.  If you make changes to the configuration in the Customization Manager, and you notice that they are not taking effect, you should restart your System Manager on your ILLiad server.

If you run into problems and want to see the log, please check these instructions:  https://github.com/Hypolymer/AddonsLibrary/wiki/Enabling-ILLiad-Client-and-Server-Logs

This System Addon is typically used in conjunction with the [ILLiad Alma NCIP Lending Addon](https://github.com/Hypolymer/ILLiad_Alma_NCIP_Lending)  and the [ILLiad Alma NCIP Borrowing Addon](https://github.com/Hypolymer/ILLiad_Alma_NCIP_Borrowing/).

| Configuration Value        | Description |
|:------------- | :-----|
|FieldToUseForBarcode|This setting determines what field you use to get the barcode from the ILLiad TN to send to Alma.  If blank, the Addon will use the TransactionNumber field.|
|NCIP_Responder_URL|The URL used to connect to your Alma NCIP responder. Replace "xxx" with your institution's three letter Alma code. If SUNY, replace "xxx" with "suny-zzz", and replace zzz with your institution's three letter Alma code.|
|renewItem_from_uniqueAgency_value| Your institution's Alma code.  This could be a three-letter code, or a hyphenated code like "SUNY_GEN".|
|ApplicationProfileType|Input the Resource Sharing Partner code used in Alma.  Possible values might be "ILL" or "ILLiad".|
|RenewItemSearchQueue|The queue the addon will monitor to process requests.|
|RenewItemSuccessQueue|This designates the name of the queue a Borrowing Transaction will be moved to if the RenewItem function is successful.|
|RenewItemFailQueue|This designates the name of the queue a Borrowing Transaction will be moved to if the RenewItem function fails.|
