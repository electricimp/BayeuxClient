# Test Instructions #

The tests in the current directory are intended to check the behavior of the BayeuxClient library. They are written for and should be used with [*impt*](https://github.com/electricimp/imp-central-impt). Please see the [*impt* Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for details on how to configure and run the tests.

## Salesforce Test Setup ##

The [Salesforce.agent.test.nut](./Salesforce.agent.test.nut) test uses the Salesforce platform and requires setup as described below. 

The other tests can be [run](#run-tests) without any setup.

### Configure Salesforce ###

1. [Login To Salesforce](../examples/README.md#login-to-salesforce)
1. [Create a Salesforce Connected Application and obtain a **Consumer Key** and a **Consumer Secret**](../examples/README.md#create-a-salesforce-connected-application)
1. [Create a Salesforce Platform Event](../examples/README.md#create-platform-event-in-salesforce)
1. Obtain a **Username** and a **Security token**:
    1. Launch your Developer Edition organization.
    1. On the Salesforce page, click your profile icon in the top-right navigation menu and select **Settings**:
![Click your profile icon in the top-right navigation menu and select Settings](images/Settings.png "Click your profile icon in the top-right navigation menu and select Settings")
    1. Make a note of your **Username**.
    1. Enter **Reset** in the Quick Find box and then select **Reset My Security Token**:
![Type Reset in the Quick Find box and then select Reset My Security Token](images/ResetToken.png "Type Reset in the Quick Find box and then select Reset My Security Token")
    1. Click the **Reset Security Token** button.
    1. You will now get an email from Salesforce with your new **Security token**. It will be needed in the next step.

### Set Environment Variables ###

- Set *SALESFORCE_TEST_CONSUMER_KEY* environment variable to the value of **Consumer Key** obtained earlier.\
The value should look like `3MVG9mIli7ewofGtFMOuXXXXXXXX4ylsz6cdDZ4kjtqwZn256uEhQkM1ubTnktUdZViw2tfBgcNidXJOlHUv8`.
- Set *SALESFORCE_TEST_CONSUMER_SECRET* environment variable to the value of **Consumer Secret** obtained earlier.\
The value should look like `34956xxxxx2882569`.
- Set *SALESFORCE_TEST_USERNAME* environment variable to the value of your **Username** obtained earlier.\
The value should look like `aaa@bbb.ccc`.
- Set *SALESFORCE_TEST_PASSWORD* environment variable to the value of your **Salesforce Password** **CONCATENATED** with the **Security token** obtained earlier.\
The value should look like `yourpasswordXXXXXXSECURITYTOKENXXXXXX`.
- For integration with [Travis](https://travis-ci.org) set *EI_LOGIN_KEY* environment variable to the valid impCentral login key.

## Run Tests ##

- See the [*impt* Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for details on how to configure and run the tests.
- Run [*impt*](https://github.com/electricimp/imp-central-impt) commands from the root directory of the library. It contains a default test configuration file which should be updated by *impt* commands for your testing environment (the Device Group must be updated).
