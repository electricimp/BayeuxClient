# Bayeux Client Examples #

This document describes the example applications provided with the [BayeuxClient library](../README.md).

## Salesforce example ##

The example:
- authenticates the device on Salesforce platform using the provided Consumer Key and Consumer Secret
- subscribes to the events channel created on Salesforce during the setup
- periodically (every 10 seconds) sends an event to the cloud. The event contains the current timestamp
- logs all events received from the cloud (exactly the events sent in the previous point)

This example uses the [Salesforce library](https://github.com/electricimp/Salesforce) for sending the events and the [BayeuxClient library](../README.md) for receiving them.

Source code: [Salesforce.agent.nut](./Salesforce.agent.nut)

## Example Setup and Run ##

### Login To Salesforce ###

Login to [Salesforce Developer Edition org](https://login.salesforce.com/).
If you are not registered as a developer, [create a developer's account](https://developer.salesforce.com/signup).

### Set Up Imp Device ###

1. [Set up a device](https://developer.electricimp.com/gettingstarted)
1. In the [Electric Imp's IDE](https://ide.electricimp.com) create new Product and Development Device Group.
1. Assign the device to the newly created Device Group.
1. Copy the [Salesforce example source code](./Salesforce.agent.nut) and paste it into the IDE as the agent code.
1. Make a note of the agent's URL. It will be required for the next steps.
![Make a note of the agent's URL](images/AgentURL.png "Make a note of the agent's URL")
1. Leave impCentral open in your browser &mdash; you will be returning to it later.

### Create a Salesforce Connected Application ###

This stage is used to authenticate the imp application in Salesforce.

1. Launch your Developer Edition org.
1. Click the **Setup** icon in the top-right navigation menu and select **Setup**.
![Select Setup from the top-right gearwheel icon](images/Setup.png "Select Setup from the top-right gearwheel icon")
- Enter **App Manager** in the **Quick Find** box and then select **AppManager**.
![Type App Manager into the Quick Find box and then click on App Manager](images/AppManager.png "Type App Manager into the Quick Find box and then click on App Manager")
1. Click **New Connected App**.
1. In the **New Connected App** form, fill in:
    1. In the **Basic Information** section:
        1. Connected App Name: **Electric Imp Example**
        1. API Name: this will automatically become **Electric_Imp_Example**.
        1. Contact Email: enter your email address.
    1. In the **API (Enable OAuth Settings)** section:
        1. Check **Enable OAuth Settings**.
        1. Callback URL: enter the agent URL of your device (copy it from impCentral &mdash; see the previous step).
    1. Under **Selected OAuth Scopes**:
        1. Select **Access and manage your data (api)**.
        1. Click **Add**.
![You need to enable OAuth for your agent URL in the App Manager](images/OAuth.png "You need to enable OAuth for your agent URL in the App Manager")
    1. Click **Save**.
    1. Click **Continue**.
1. You will be redirected to your Connected App’s page.
    1. Make a note of your **Consumer Key** (you will need to enter it into your agent code).
    1. Click **Click to reveal** next to the **Consumer Secret** field.
    1. Make a note of your **Consumer Secret** (you will need to enter it into your agent code).
![Make a note of your Salesforce connected app Consumer Secret and Consumer Key](images/Credentials.png "Make a note of your Salesforce connected app Consumer Secret and Consumer Key")
1. Do not close the Salesforce page.

**Note:** any Salesforce Connected Application works only for the one agent the URL of which you entered in the OAuth Settings section.

### Create Platform Event in Salesforce ###

Platform Events transfer the data from the device to Salesforce.

The Platform Event fields must have the names and types mentioned here. If you change anything in the Platform Event definition, you will need to update the imp application’s agent code. The names of the Platform Event and its field are entered into the agent code as constants *EVENT_NAME* and *EVENT_FIELD_NAME*.

1. On the Salesforce page, click the **Setup** icon in the top-right navigation menu and select **Setup**.
![Select Setup from the top-right gearwheel icon](images/Setup.png "Select Setup from the top-right gearwheel icon")
1. Enter **Platform Events** into the **Quick Find** box and then select **Data > Platform Events**.
![Type Platform Events into the Quick Find box and then click on Data and then Platform Events](images/PlatformEvents.png "Type Platform Events into the Quick Find box and then click on Data and then Platform Events")
1. Click **New Platform Event**.
1. In the **New Platform Event** form, fill in:
    1. Field Label: **Test Event**
    1. Plural Label: **Test Events**
    1. Object Name: **Test_Event**
![Set up a Platform Event](images/PlatformEventSetup.png "Set up a Platform Event")
    1. Click **Save**.
1. You will be redirected to the **Test Event** Platform Event page.
Now you need to create a Platform Event field.
In the **Custom Fields & Relationships** section, click **New** to create the field.
![Add new field to the new Platform Event](images/AddField.png "Add new field to the new Platform Event")
1. In the **New Custom Field** form:
    1. Data Type: **Text**
    1. Click **Next**.
    1. Field Label: **My Timestamp**
    1. Length: **16**
    1. Field Name: **My_Timestamp**
    1. Click **Save**.
1. Make sure that the **Test Event API Name** is **Test_Event__e** and that **Custom Fields & Relationships** contains **My Timestamp** field with **My_Timestamp__c** API Name.

### Adding API Keys to Your Agent Code ###

1. Return to impCentral.
1. Find the *SALESFORCE CONSTANTS* section at the **end** of the agent code, and enter the **Consumer Key** and **Consumer Secret** from the step above as the values of the *CONSUMER_KEY* and *CONSUMER_SECRET* constants, respectively.
![In impCentral, add your Salesforce connected app Consumer Secret and Consumer Key to the places provided in the agent code](images/SetConstants.png "In impCentral, add your Salesforce connected app Consumer Secret and Consumer Key to the places provided in the agent code")
1. Again, do not close impCentral.

### Build and Run the Electric Imp Application ###

1. Click **Build & Run All** to syntax-check, compile and deploy the code.
1. On the log pane, you should see **Log in please** message. This example uses OAuth 2.0 for authentication, and the agent has been set up as a web server to handle the authentication procedure.
    1. Click the agent URL in impCentral.
![In impCentral, click the Build and Run All button to compile and deploy the application and begin device and agent logging](images/Run.png "In impCentral, click the Build and Run All button to compile and deploy the application and begin device and agent logging")
    1. You will be redirected to the login page.
    1. Log into Salesforce *on that page*.
    1. If login is successful, the page should display **Authentication complete - you may now close this window**.
    1. Close that page and return to impCentral.
1. Make sure there are no errors in the logs.
1. Make sure there are periodic logs like this:
![Make sure there are periodic logs like this](images/PeriodicLogs.png "Make sure there are periodic logs like this")
1. Your application is now up and running.
1. You may check that the value of the **My_Timestamp__c** field in the received event is equal to the value in the sent event.
