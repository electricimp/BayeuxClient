# Bayeux Client Salesforce Example #

This example uses the [Salesforce library](https://github.com/electricimp/Salesforce) to send the events and the [BayeuxClient library](../README.md) to receive them. The example illustrates the following:

- Authenticating the device with Salesforce using the [OAuth2 library](https://github.com/electricimp/OAuth-2.0) Device Flow via a Salesforce Connected Application.
- Subscribing to the events channel created during the Salesforce example setup.
- Periodically (every ten seconds) sending an event to the Salesforce cloud. The event contains the current timestamp and the device ID.
- Logging all events received from the cloud, ie. the events sent in the previous point.

## Source Code ##

[SalesforceOAuth2Example.agent.nut](./SalesforceOAuth2Example.agent.nut)

## Electric Imp And Salesforce Configuration  ##

### Set Up An imp-enabled Device ###

For more detailed instructions on getting started with Electric Imp, please visit the Electric Imp Dev Center’s [getting started guide](https://developer.electricimp.com/gettingstarted).

1. In [Electric Imp’s impCentral™](https://impcentral.electricimp.com) create new a Product and a Development Device Group.
1. Activate a new Electric Imp device using BlinkUp™ or select an unused device from your account.
1. Assign the device to the newly created Device Group.
1. Copy the [Salesforce example source code](./SalesforceOAuth2Example.agent.nut) and paste it into Device Group’s code editor as the agent code. This example has no device code, so leave the device code pane blank.
1. Leave impCentral open in your browser &mdash; you will be returning to it later.

### Login To Salesforce ###

If you are not registered as a developer, [create a developer account](https://developer.salesforce.com/signup) now.

Now log in to [Salesforce Developer Edition org](https://login.salesforce.com/).

### Create A Salesforce Connected Application ###

The Salesforce **Connected Application** is used to authenticate your devices with Salesforce. This example will contain detailed instructions on how to use an OAuth2 Device Flow with the Connected Application’s **Consumer Key** and **Consumer Secret** to authenticate imp-enabled devices.

1. Click the gear icon in the top-right navigation menu and select **Setup**:
![Select Setup from the top-right gearwheel icon](images/Setup.png "Select Setup from the top-right gearwheel icon")
1. Enter `App Manager` in the **Quick Find** box and then select **AppManager**:
![Type App Manager into the Quick Find box and then click on App Manager](images/AppManager.png "Type App Manager into the Quick Find box and then click on App Manager")
1. Click **New Connected App**.
1. In the **New Connected App** form, enter:
    - In the **Basic Information** section:
        - Connected App Name: `Electric Imp Example`.
        - API Name: this will automatically become `Electric_Imp_Example`.
        - Contact Email: enter your email address.
    - In the **API (Enable OAuth Settings)** section:
        - Check **Enable OAuth Settings**.
        - Check **Enable Device Flow**.
        - Callback URL should auto fill with `https://login.salesforce.com/services/oauth2/success`.
        -  Under **Selected OAuth Scopes**:
            - Select **Access and manage your data (api)**.
            -  Click **Add**
            - Select **Perform requests on your behalf at any time (refresh_token, offline_access)**.
            -  Click **Add**
![Enable Connected App OAuth Settings](images/ConnectedAppAPIOAuthSettings.png "You need to enable OAuth for your agent URL in the App Manager")
    - Click **Save**.
    - Click **Continue**.
1. You will be redirected to your Connected App’s page.
    - Make a note of your **Consumer Key** (you will need to enter it into your agent code).
    - Click **Click to reveal** next to the **Consumer Secret** field.
    - Make a note of your **Consumer Secret** (you will need to enter it into your agent code):
![Make a note of your Salesforce connected app Consumer Secret and Consumer Key](images/Credentials.png "Make a note of your Salesforce connected app Consumer Secret and Consumer Key")
1. **Do not close the Salesforce page**.

### Create A Platform Event In Salesforce ###

Platform Events transfer the data from the device to Salesforce.

**Note** The API names for the platform event and the event fields must match those used in the code. The instructions below contain API names that match the current example code. If these names are altered in any way, the values of the **EVENT_NAME** constant and the **EVENT_FIELDS** enum (found under the **APPLICATION CLASSES** section in the code) will need to be updated.

1. Navigate back to the **Salesforce Setup Home** by clicking the gear icon in the top-right navigation menu of your Salesforce webpage and selecting **Setup**:
![Select Setup from the top-right gearwheel icon](images/Setup.png "Select Setup from the top-right gearwheel icon")
1. Enter `Platform Events` into the **Quick Find** box and then select **Integrations > Platform Events**:
![Type Platform Events into the Quick Find box and then click on Data and then Platform Events](images/PlatformEvents.png "Type Platform Events into the Quick Find box and then click on Data and then Platform Events")
1. Click **New Platform Event** button on the Platform Events page.
1. In the **New Platform Event** form, enter:
    - Field Label: `Test Event`
    - Plural Label: `Test Events`
    - Object Name: `Test_Event`:
![Set up a Platform Event](images/PlatformEventSetUpNew.png "Set up a Platform Event")
    - Click **Save**
1. You will be redirected to the **Test Event** Platform Event page. Now you need to create a two Platform Event fields. In the **Custom Fields & Relationships** section, click **New** to create the field:
![Add new field to the new Platform Event](images/AddField.png "Add new field to the new Platform Event")
1. In the **New Custom Field** form, enter:
    - Data Type: **Text**.
    - Click **Next**.
    - Field Label: **My Timestamp**.
    - Length: **20**.
    - Field Name: **My_Timestamp**.
    - Click **Save**.
1. Repeat creating a new field steps to add the `Device Id` Field. In the **Custom Fields & Relationships** section, click **New** & in the **New Custom Field** form, enter:
    - Data Type: **Text**.
    - Click **Next**.
    - Field Label: **Device Id**.
    - Length: **16**.
    - Field Name: **Device_Id**.
    - Click **Save**.
1. Confirm that the API Names for the **Platform Event** and **Fields** match the code.
    - If you have altered the names used in these instructions, you will need to update the **EVENT_NAME** constant and the **EVENT_FIELDS** enum found under the **APPLICATION CLASSES** section.
    - If you have kept the names used in these instructions the API names will be as follows:
        - **Test Event API Name** is `Test_Event__e`
        - **Custom Fields & Relationships** contains two fields:
            - **My Timestamp API Name** is `My_Timestamp__c`
            - **Device Id API Name** is `Device_Id__c`

## Run Example Application And Authenticate Device ##

### Add API Keys To Your Agent Code ###

1. Return to the impCentral webpage.
1. Find the *SALESFORCE CONSTANTS* section at the **end** of the agent code, and enter the **Consumer Key** and **Consumer Secret** from the steps above as the values of the *CONSUMER_KEY* and *CONSUMER_SECRET* constants, respectively:
![In impCentral, add your Salesforce connected app Consumer Secret and Consumer Key to the places provided in the agent code](images/SetConstantsNew.png "In impCentral, add your Salesforce connected app Consumer Secret and Consumer Key to the places provided in the agent code")
1. Again, **do not close impCentral**.

### Start The Electric Imp Application ###

1. Click **Build and Force Restart** to syntax-check, compile and deploy the code.

### Authenticate The Device ###

1. In the log pane, you should see a `Authorization is pending. Please grant access` message. This example uses OAuth 2.0 Device Flow for authentication, and the agent URL has been configured to launch a web page to help with device authentication.
    - Click the agent URL in impCentral:
![In impCentral, click Agent URL to launch authorization process](images/AuthLogs.png "In impCentral, click Agent URL to launch authorization process")
    - A new tab will open and you will see simple webpage where you can easily copy the **Device Authentication Code**. Once you have clicked to copy the code, click on the login redirect link.
    - You will be redirected to a Salesforce Page where you can paste the **Device Authentication Code** into a form. If for any reason the copy/paste did not work, you can go back to ImpCentral and look in the logs for the Device Code. Paste the code into the form and click **Connect**.
    - You will be redirected a to more Salesforce Authentication pages. Follow the instructions on each webpage to grant access to your Salesforce account. If you are not logged into Salesforce already you will be asked to log in.
    - Once authorization is completed, you will be redirected to your Salesforce account homepage. Close that page and return to impCentral.

### Check Application Logs ###

If authentication was successful, your application will have already started sending data to Salesforce.

1. Make sure there are no errors in the logs.
1. Make sure there are periodic logs like this:
![Make sure there are periodic logs like this](images/AgentLogsNew.png "Make sure there are periodic logs like this")
1. You may check that the value of the **My_Timestamp__c** field in the received event is equal to the value in the sent event.
