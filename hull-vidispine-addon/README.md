# The hull-vidispine-addon chart

This helm chart is used to provide Vidispine specific functionality to Helm charts that are built upon the HULL library.

## The hull-install and hull-configure job

The `hull-install` and `hull-configure` jobs are special Kubernetes jobs included in this addon chart `hull-vidispine-addon.yaml` which can be enabled or disabled via configuration. They can communicate with custom APIs to create entities which are needed for the product to function fully in the given system.

Typically there are two general scenarios for installing a Vidispine product:
- installation in a Vidispine only environment (e.g. VidiNet, MediaLogger standalone) with
  - registration in Vidispine 
- installation in a Vidispine enterprise environment with
  - registration in Authentication Service
  - registration in ConfigPortal
but the `hull-install` and `hull-configure` jobs can communicate with a large number of APIs in general.

Technically the `hull-install` and `hull-configure` jobs run as so-called Helm hook, this means that the whole installation process pauses while the job runs. The major technical difference between `hull-install` and `hull-configure` is that `hull-install` is a Kubernetes job exectuted initially **before the main pods of the application have started up** and `hull-configure` is executed **after the main pods of the application have started up**. Only on successful execution of both jobs (if enabled) the installation itself becomes successful.

From a functional perspective the **`hull-install` job is used to create the necessary prerequisites to run an application in the Kubernetes cluster** and the **`hull-configure` job being the counterpart is mostly used to configure the installed applications themselves**. It's main purpose is therefore to communicate with APIs that the product provides during its installation to apply initial configuration. Prominent uses are to add default metadata to a ConfigPortal installation that was created within the same Helm Chart or initialize VidiCore via its API after setup. Technically it is the same process as running the `hull-install` job, the only difference is that it will only apply configuration of `subresources` that are tagged with `stage: post-install`. If no `stage` tag or `stage: pre-install` is given for a subresource it will be handled by the `hull-install` job by default. 

**Note that the `hull-install` job is enabled by default and `hull-configure` is not enabled by default.**

## Execution and Configuration

The `hull-install` and `hull-configure` jobs run as PowershellCore containers and execute a pre-configured Powershell script. The configuration for the script is derived from the configuration specified in `hull-vidispine-addon.values.yaml` at 

```yaml
hull:
  config:
    general:
      data:
        installation:
```

To define entities that shall be created, updated or deleted in an API, you need to provide the `endpoint`, `subresource` and `entity` to identify the target of the operation. 

For example, in `https://host.docker.internal/authservice/v1/Client/configportalclient`  
- the `endpoint` is `https://host.docker.internal/authservice` 
- the `subresource` is `v1/Client` and
- the `entity` is `configportalclient` 

To mimic this tree structure the configuration is built around this three-part way of specifying API paths. The configuration section `installation` hence has the following structure:

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `config` | Additional configuration options.<br><br>Key: <br>One of the allowed options defined in <br>`<configSpec>`<br><br>Value: <br>The configuration options value | `customCaCertificates`<br>`preScript`<br>`postScript`<br>`productUris`<br>`debug`
| `endpoints` | Dictionary of endpoints to communicate with.<br><br>Key: <br>Key for entry in dictionary `endpoints`<br><br>Value: <br>The endpoint definition in form of a `<endpointSpec>` | `10_vidicore:`<br>`20_authservice:`<br>`30_configportal:`

### ConfigSpec
Describes configuration options. <br>Has exclusively the following sub-fields: <br><br>`customCaCertificates`<br>`preScript`<br>`postScript`<br>`productUris`<br>`debug`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `customCaCertificates` | An optional dictionary of custom ca certificates that are being mounted into the`hull-install` and `hull-configure` pods. Presence of certificates may be required for proper communication with the authentication service.
| `preScript` | A Powershell script to be executed before the installation jobs endpoints are processed. 
| `postScript` | A Powershell script to be executed after the installation jobs endpoints are processed. 
| `productUris` | Product URIs that are can be used in conjunction with the transformations that populate authentication client data such as `hull.vidispine.addon.coruris` and `hull.vidispine.addon.producturis`. <br><br>When populated the entries here will be manipulated according to the transformation and are added to the fields where the transformation is applied. <br><br>Note that this can be automatically populated by a `hull.util.transformation.tpl` from the `hull.config.general.data.endpoints` fields like in the example. | `[]` | `productUris:`<br>`-`&#160;`https://myapp`<br>`-`&#160;`https://myappalternativehost`<br><br>or<br><br>`productUris:`<br>&#160;&#160;`_HULL_TRANSFORMATION_:`<br>&#160;&#160;&#160;&#160;`NAME:`&#160;`hull.util.transformation.tpl`<br>&#160;&#160;&#160;&#160;`CONTENT:`&#160;`"`<br>&#160;&#160;&#160;&#160;&#160;&#160;`[`<br>&#160;&#160;&#160;&#160;&#160;&#160;`{{-`&#160;`(index`&#160;`.`&#160;`\"PARENT\").Values.hull.config.general.data.endpoints.configportal.uri.api`&#160;`-}},`<br>&#160;&#160;&#160;&#160;&#160;&#160;`{{-`&#160;`(index`&#160;`.`&#160;`\"PARENT\").Values.hull.config.general.data.endpoints.configportal.uri.ui`&#160;`-}}`<br>&#160;&#160;&#160;&#160;&#160;&#160;`]"`
| `debug` | Debug configuration options. | `debug:`<br>&#160;&#160;`ignoreEntityRestCallErrors:`&#160;`false`<br>&#160;&#160;`retriesForEntityRestCall:`&#160;`3`<br>&#160;&#160;`retriesForAuthServiceCall:`&#160;&#160;`5` | `debug:`<br>&#160;&#160;`ignoreEntityRestCallErrors:`&#160;`true`<br>&#160;&#160;`retriesForEntityRestCall:`&#160;`1`<br>&#160;&#160;`retriesForAuthServiceCall:`&#160;`1`
| `debug.ignoreEntityRestCallErrors` | If `false`, the `hull-install` and `hull-configure` scripts will stop after an error was encountered and the allowed number of retries was exceeded. To instead ignore errors and provide a list of failed `entities` after execution set this value to `true`, This can be useful for debugging potential issues with Helm Charts. | `false` | `true`
| `debug.retriesForEntityRestCall` | Sets number of retries for each individual GET, PUT, POST and DELETE call before considering the operation failed. | `3` | `1`
| `debug.retriesForEntityRestCall` | Sets number of retries for each individual GET, PUT, POST and DELETE call before considering the operation failed. | `5` | `2`

### EndpointSpec
Describes an endpoint which is communicated with. <br>Has exclusively the following sub-fields: <br><br>`endpoint`<br>`auth`<br>`extraHeaders`<br>`stage`<br>`subresources`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `endpoint` | The HTTP/HTTPS path to the endpoint API <br><br>If this is not defined, nothing will be attempted to be written to this endpoint | | `https://vpms3testsystem.westeurope.cloudapp.azure.com:19081/Authentication/Core`<br>or<br>`http://dv-ndr-plat4.s4m.de:31060` 
| `auth` | Defines how to authenticate at the given endpoint<br><br>Has one of following keys:<br>`basic`<br>`token` |
| `auth.basic` | Defines basic authentication for connecting to API | | `env:`<br>&#160;&#160;`username:`&#160;`VIDICORE_ADMIN_USERNAME`<br>&#160;&#160;`password:`&#160;`VIDICORE_ADMIN_PASSWORD`
| `auth.basic.env.username` | Defines the environment variable that holds the username for basic auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `username` environment variable
| `auth.basic.env.password` | Defines the environment variable that holds the password for basic auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `password` environment variable
| `auth.token` | Defines token authentication for connecting to API | | `authenticationServiceEndpoint:`&#160;`"https://vpms3testsystem.westeurope.cloudapp.azure.com:19081/Authentication/Core"`<br>`env:`<br>&#160;&#160;`clientId:`&#160;`AUTHSERVICE_TOKEN_PRODUCT_CLIENT_ID`<br>&#160;&#160;`clientSecret:`&#160;`AUTHSERVICE_TOKEN_PRODUCT_CLIENT_SECRET`<br>`grantType:`&#160;`"client_credentials"`<br>`scopes:`<br>`- 'configportalscope'`<br>`- 'identityscope'`
| `auth.token.authenticationServiceEndpoint` | Endpoint of AuthenticationService to get token from |
| `auth.token.env.clientId` | Defines the environment variable that holds the clientId for token auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `clientId` environment variable
| `auth.token.env.clientSecret` | Defines the environment variable that holds the clientSecret for token auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `clientSecret` environment variable
| `auth.token.grantType` | Defines the grantType for the token
| `auth.token.scopes` | Defines the scopes for the token | `[]` 
| `stage` | Global stage where the defined `subresources` are processed. Can be overwritten at `subresource` level individually. <br>All subresources are by default processed during execution of the `hull-install` job by setting stage `pre-install` before installation of the main product of the parent Helm Chart. If you for example need to communicate to the API of a product you just installed within the parents Helm chart, set the `stage` to `post-install` and the processing takes places within the `hull-configure` job after the main product installation is done. | `pre-install` | `post-install`
| `extraHeaders` | Globally added extra headers to HTTP calls. Header keys defined on the `endpoint` level will be set for all entities with the headers value when sending HTTP requests. However header values can be overwritten or added individually on the `entity` level via the local `extraHeaders` dictionary. | `` | `extraHeaders:`<br>&#160;&#160;`added_header_1:`&#160;`header_value`<br>&#160;&#160;`added_header_2:`&#160;`another_header_value`
| `subresources` | Dictionary of individual API routes to communicate with.<br><br>Key: <br>Key for entry in dictionary `subresources`<br><br>Value: <br>The subresource definition  in form of a `<subresourceSpec>`

### SubresourceSpec
Describes a subresource on an endpoint which is communicated with. <br>Has exclusively the following sub-fields: <br><br>`apiPath`<br>`typeDescription`<br>`identifierQueryParam`<br>`_DEFAULTS_`<br>`entities`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `apiPath` | The relative path of the API on the endpoint | | `v1/Resource/ApiResource` 
| `typeDescription` | Description of the subresource 
| `identifierQueryParam` | Some APIs handle deletion of entities by DELETEing the parent resource and specifying the entity to delete in a query parameter. If the subresource handles DELETEion in that way, the query parameter to use for identifying the object needs to be stated here. If empty or unspecified, DELETE calls will be made to the path which ends with the entities name. ||   `"Guid"`
| `stage` | Stage where this `subresource` is processed. Overwrites `stage` from `endpoint` level. <br>All subresources are by default processed during execution of the `hull-install` job by setting stage `pre-install` before installation of the main product of the parent Helm Chart. If you for example need to communicate to the API of a product you just installed within the parents Helm chart, set the `stage` to `post-install` and the processing takes places within the `hull-configure` job after the main product installation is done. | `pre-install` | `post-install`
| `auth` | Allows to override the `endpoint`s `auth` configuration at the `subresource` scope<br><br>Has one of following keys:<br>`basic`<br>`token` 
| `_DEFAULTS_` | Defaults for all `entity` objects defined under this `endpoint`. Can be used to set all `entity` properties to a default value. Technically all `entity` values will be merged on top of the `_DEFAULTS_` | | `_DEFAULTS_:`<br>&#160;&#160;`register:`&#160;`true`<br>&#160;&#160;`overwriteExisting:`&#160;`false`
| `entities` | Dictionary of entities on the subresource to create, modify or delete.<br><br>Key: <br>Key for entry in dictionary `entities`<br><br>Value: <br>The entity definition in form of a `<entitySpec>` 

### EntitySpec
Describes a particular entity on a subresource on an endpoint which is communicated with. <br>Has exclusively the following sub-fields: <br><br>`register`<br>`remove`<br>`identifier`<br>`putUriExcludeIdentifier`<br>`putInsteadOfPost`<br>`postQueryParams`<br>`overwriteExisting`<br>`getUriExcludeIdentifier`<br>`getCustomScript`<br>`noGet`<br>`contentType`<br>`config`<br>`extraHeaders`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `register` | If set to true, the entity will be created or modified | 
| `remove` | The entity will be DELETEd if it exists
| `identifier` | Optional field to specify the objects 'identifier', if not set or empty the object 'identifier' will be set to the key of the entity. The identifier is important for making a standard GET call to determine if the entity already exists, it provides the last part of the GET uri, for example `https://host.com/API/notifications/groups/NOTIFICATION-VX-99`. <br><br>Note that this setting is irrelevant if either `noGet` or `getUriExcludeIndentifier` are set to `true`.<br><br>A typical usecase for this is having an object being identified by a GUID but wanting to use a more speaking name for the entity key or utilize the ordering via suitable key names instead of using a non-speaking GUID.'  | 
| `putUriExcludeIdentifier` | Some APIs handle PUTting of entities by PUTing to the parent resource and specifying the entity to create in the body. If the subresource handles PUTting in that way, set this parameter to `true`. If `false` or unspecified, PUT calls will be made to the path which ends with the entities name.
| `putInsteadOfPost` | Some APIs use PUTting instead of POSTing for creation of new entities. If the subresource uses PUTting instead of POSTing, set this parameter to `true`.
| `postQueryParams` | Query Parameters to add to the Url of a POST command. Not a frequent usa case but required to submit for example the `guid` of a UseCaseDefinition to migrate.
| `overwriteExisting` | The default behavior is to not overwrite existing entities in case they already exist. Set this field to `true` to overwrite any existing entity.
| `getUriExcludeIdentifier` | Normally in a REST style API GET calls include the identifier of the object as the last segment of the URI. By setting this to `true` GET calls will not include the identifier segment. The use of this is for some specific APIs the usual REST style is not used and it may be required to make a GET call to the object resource and process the result via `getCustomScript` functionality. Hence normally only set this to `true` if you need to do custom processing with `getCustomScript` of the result to update the `$uriGet` and/or `$uriDelete` parameters. | `false` | `true`
| `getQueryParams` | Query Parameters to add to the Url of a GET command, for example for filtering from a list of objects. 
| `getCustomScript` | Offers the possibility to provide a custom Powershell script that further processes the result of the GET call. May be used in conjunction with setting `getUriExcludeIdentifier` to true.<br><br>Using a custom script, variables from the outer script can be read and used within the script, so you may find it useful to access the following local variables in the script: <br><br>`$responseGet`: the string result of the GET call<br>`$apiEndpoint`: the apiEndpoint field of the subresource<br><br>The script can return either a boolean value for general success of the GET call (translating to a 200 or 404 status code) or it may return a JSON with additional information useful for adjusting a subsequent PUT or DELETE call. The JSON is allowed to return the following fields that will update the local PowerShell variables accordingly if present:<br><br>`statusCode`: sets the virtual statusCode for further processing<br>`uriPut`: sets the full URI used for putting the `config` content.<br>`uriDelete`: sets the full URI used for deleting the entity.<br><br>A JSON returned from `getCustomScript` may look like this: `{"statusCode":200, "uriPut":"https://host.com/API/notifications/groups/NOTIFICATION-VX-99"}`<br>An example of this coming together is the usage of notifications in VidiCore, to find out whether a particular notification needs to be updated it is required to get a list of all existing notifications and update the POST/DELETE uri to correctly address the targeted resource. See the VidiCore or MediaPortal Helm Chart for the implementation of this. 
| `noGet` | If `true` the check for existence is skipped and a PUT or POST is done directly. This is treated same as receiving a 404 on the GET request.
| `contentType` | The content type header for POST or PUT of the entity `config` and the accept header for all calls. Supported choices are `application/json`, `application/xml` and `text/plain`. Defaults to `application/json`.
| `extraHeaders` | Locally added extra headers to HTTP calls. Header keys defined on the `entity` level have highest precedence, overwriting `extraHeaders` added on the `endpoint` level. | `` | `extraHeaders:`<br>&#160;&#160;`added_header_1:`&#160;`header_value`<br>&#160;&#160;`added_header_2:`&#160;`another_header_value`
| `readConfigFromFile` | If provided a value, the complete content of the `config` field is read from a local file during deployment. <br><br>To use this feature, the file being refered to needs to be mounted into the `hull-install` or `hull-configure` job's pod via providing an additional `volume` and `volumeMount`. | `` | `readConfigFromFile:`&#160;`/workflows/workflow-do-deploy.yaml`
| `readConfigValuesFromFiles` | Allows to either map complete file contents to a JSON key in `config` or the contents from a particular JSON key from a file to a JSON key in `config`. The content of this field if provided must be a dictionary where the key is the target JSON key in `config` and the value has two fields: <br><br>`path`:  mandatory and points to the mounted file's path, the source file can be of any text format <br> `key`: optional and if specified declares the source files JSON key to import, for this to work the source file must be a JSON file.<br><br>To use this feature, the files being refereed to needs to be mounted into the `hull-install` or `hull-configure` job's pod via providing an additional `volume` and `volumeMount`. | `` | `readConfigFromFile:`&#160;`/workflows/workflow-do-deploy.yaml`| `config` | The free-form body of the request. For `contentType` of `application/json` the content of `config` is YAML so when PUTting or POSTing to APIs the content is converted from YAML to JSON and sent with header `Content-Type: application/json`. For `contentType` `application/xml` and `text/plain` the `config` is a string which must resemble proper XML for usage with `contentType` `application/xml`. | | `Name:`&#160;`Publish`<br>`Guid:`&#160;`c9689fe0-a0e9-40d7-af82-500bba342b62`<br>`UseCaseGroupName:`&#160;`Publish`<br>`UseCaseGroupOrderNo:`&#160;`2`<br>`OrderNo:`&#160;`1`<br>`ProductGuid:`<br>`- 62e052b1-6864-4502-87dc-944be4f5d783`<br>`UseCaseType:` `dynamic`<br>`Json:`&#160;`|`<br>&#160;&#160;`{"Overview":{"AllowToggleView":false,`<br>&#160;&#160;`"View":"detailed","Columns":[]},`<br>&#160;&#160;`"Fields:"`<br>&#160;&#160;`[{"Name":"targetStorage","DisplayName":"Target`<br>&#160;&#160;`Storage","Type":"VS_Storage","IsRequired":true,`<br>&#160;&#160;`"InputProperties":{"Storage":"Storage"}},`<br>&#160;&#160;`{"Name":"userSelectableWF",`<br>&#160;&#160;`"DisplayName":"User-Selectable`&#160;`Workflows",`<br>&#160;&#160;`"Type":"Multiple_Workflow",`<br>&#160;&#160;`"IsRequired":true},`<br>&#160;&#160;`{"Name":"userSelectableMetadata",`<br>&#160;&#160;`"DisplayName":"User-Selectable Metadata",`<br>&#160;&#160;`"Type":"CustomInput_MaskedControl"}],"Actions":`<br>&#160;&#160;`[{"IsEnabled":true,"Name":"Edit","OrderNo":1,`<br>&#160;&#160;`"TooltipMessage":"Edit this Publish `<br>&#160;&#160;`Configuration","Type":"edit"},`<br>&#160;&#160;`{"IsEnabled":true,`<br>&#160;&#160;`"Name":"Workflow Designer","OrderNo":3,`<br>&#160;&#160;`"TooltipMessage":"Open Workflow Designer",`<br>&#160;&#160;`"Type":"openWorkflow",`<br>&#160;&#160;`"SystemEndpointName":"workflow designer"}]`<br>&#160;&#160;`,"AllowMultipleConfig":false}`


## Activation and Preconfiguration
Execution of Jobs can generally be selectively enabled or not by setting the `hull.objects.job.<jobKey>.enabled` field to `true` or `false`. 

By default the `hull-install` job is enabled but already pre-configured so that after enabling it not all information needs to be set. Pre-configuration means that:

- the container needed to run the job is defined so that it 
  - automatically loads the configuration section from `hull.config.general.data.installation`
  - mounts sensitive data as environment variables from secrets (which by default are created with the respective keys but without values). If you use the `hull-install` job in product installation you need to set the appropriate values in the secrets:
    - from `vidicore-secret` the `data` keys 
      - `adminUsername` to env var `VIDICORE_ADMIN_USERNAME` 
      - `adminPassword` to env var `VIDICORE_ADMIN_PASSWORD` 
    
        if communication with VidiCore is required.

    - from `authservice-token-secret` the `data` keys
      - `installerClientId` to env var `AUTHSERVICE_TOKEN_INSTALLER_CLIENT_ID` 
      - `installerClientSecret` to env var `AUTHSERVICE_TOKEN_INSTALLER_CLIENT_SECRET` 
      - `productClientId` to env var `AUTHSERVICE_TOKEN_PRODUCT_CLIENT_ID` 
      - `productClientSecret` to env var `AUTHSERVICE_TOKEN_PRODUCT_CLIENT_SECRET`

        if communication with AuthService (`installerClientId`/`installerClientSecret`) and ConfigPortal (`productClientId`/`productClientSecret`) is required.

- typical endpoints and subresources are predefined so that only entities need to be specified. The predefined subresources for the endpoints are skipped in case the endpoint is not defined. 
  - endpoint with key `10_vidicore` is set up to do basic authentication on the vidispine endpoint defined in `hull.config.general.data.endpoints.vidicore.uri.api` using the `admin` credentials from secret `vidicore-secret`
    - subresources are configured so that creating specific entities works out of the box for them
      - key `10_metadatafields` for inserting metadatafields into Vidispine
      - key `20_metadatafieldgroups` for inserting metadatafieldgroups into Vidispine  
      - keys 
        - `90_itemnotification`
        - `91_collectionnotification`
        - `92_jobnotification`
        - `93_storagenotification`
        - `94_storagefilenotification`
        - `95_filenotification`
        - `96_quotanotification`
        - `97_groupnotification`
        - `98_documentnotification`
        - `99_deletionlocknotification`
        for adding objet type notifications to VidiCore
  - endpoint with key `20_authservice` is set up to do token authentication on the authentication service endpoint defined in `hull.config.general.data.endpoints.authservice.uri.api` using the `installer` credentials from secret `authservice-token-secret`
    - subresources are configured so that creating specific entities works out of the box for them
      - key `10_resources` for inserting scopes into authentication service
      - key `20_clients` for inserting clients into authentication service
      - key `30_roles` for inserting roles into authentication service
  - endpoint with key `30_configportal` is set up to do token authentication on the ConfigPortal  endpoint defined in `hull.config.general.data.endpoints.configportal.uri.api` using the `product` credentials from secret `authservice-token-secret`
    - subresources are configured so that creating specific entities works out of the box for them
      - key `10_products` for inserting products into ConfigPortal
      - key `20_usecasedefinitions` for inserting use-case definitions into ConfigPortal
      - key `25_migrate` for making calls to the UseCaseDefinition Migrate API. Note that for these calls to be successful the `guid` of the UseCaseDefinition needs to be passed under the `guid` key in the `postQueryParams` dictionary.
      - key `30_usecaseconfigurations` for inserting use-case configurations into ConfigPortal
      - key `40_metadata` for inserting metadata definitions into ConfigPortal
      - key `45_metadatagroups` for inserting metadata group definitions into ConfigPortal
      - key `50_roles` for inserting roles into ConfigPortal
      - key `60_productcomponents` for inserting product components such as licenses
      - key `70_mappedgroups` for creating mapped groups
      - key `80_systemendpoints` for inserting system endpoint entries
Some of the keys have a numerical prefix which guarantees the order of execution is in ascending alphanumeric form. This is needed because the Go dict structure used here to store data has all keys ordered this way when retrieving them one by one. If you overwrite one of the keys you need to make sure the name including prefix is identical.

## Sourcing configuration from external files

Besides the ability to specify the configuration for `hull-vidispine-addon` it is also possible to provide it in parts via external files stored in your Helm chart. The reason for this is mainly to reduce the overall size and improve readability of the `values.yaml`. Hereby it is possible to mix dictionary entries from `values.yaml` definitions with those defined in external files as shown next. Technically two different methods are provided for integrating configuration content from external files with a different scope of application and technical implications.  

The first `installation.yaml merging` approach is suitable for providing larger configuration sections from external files, the external files content is merged at Helm chart rendering with that of the `values.yaml` to create the `installation.yaml` configuration. Hence the merged result of inline `values.yaml` and all files provided via this method will be viewable in the `installation.yaml` content of the `hull-install` secret. This is suitable for most cases where not too large files need to be managed such as UseCaseDefinitions or UseCaseConfigurations.

The second `installation.yaml reference` approach allows to place separate files into a dedicated folder of the parent's Helm Chart (`files/hull-vidispine-addon/installation/sources`) from which they are stored automatically into a secret which in turn is accessible for the `hull-install` and `hull-configure` job pods. Using the `readConfigFromFile` and `readConfigValuesFromFiles` instructions available on the `entity` specification level the file contents can serve as the complete `config` content or can be mapped to JSON properties of the `config` field. Use this approach for rather large files (licenses, workflow definitions, ...). 

When choosing either one approach, care needs to be taken to not overstep the maximum size of the Helm Charts versioned manifest secrets. For each release, Helm collects the contents of the `values.yaml`, all template files contents and all other files contained in the Helm Chart. The sum of this information must not exceed 1.5 MB of data, otherwise installation via Helm will fail. Note that the `installation.yaml merging` approach will not create additional secrets in your cluster, however it duplicates the external files data uncompresed into `values.yaml`. Using the `installation.yaml reference` approach the contents of the files imported only exists once in the overall manifest (as the source files contents) so it can be crucial for larger file contents to import them the second way to stay within the size limits.

### Details of the `installation.yaml merging` sourcing approach

Considering the following example structure within a `values.yaml` (omitting irrelevant parts with `...`):

```yaml
hull:
  config:
    general:
      data:
        installation:
          endpoints:
            20_authservice:
              subresources:
                10_clients:
                  entities:
                    entity1:
                      ...
                    entity2:
                      ...
                    entity3:
            30_configportal:
              subresources:
                20_usecasedefinitions:
                  entities:
                    large_entity1:
                      ...
                    large_entity2:
                      ...
                    large_entity3:
                     ...
                    third_party_endpoints: 
                     ...                  
```

Assume that there are three `10_clients` defined for authservice whose configuration makes up around maybe a 100 lines. And let the `20_usecasedefinitions` be significantly larger with several hundreds of lines per single definition with unminified JSON content for better readability.

One way of adding this data appropriately to the charts `installation` configuration could be to source all `10_clients` from one single `subresource` file and each `20_usecasedefinitions` from an individual `entity`file. 

To do so, create a `files` folder structure in your Helm chart like this:

```yaml
<root>
  Chart.yaml
  values.yaml
  ...  
  files
    hull-vidispine-addon
      installation
        endpoints
          20_authservice
            20_clients.yaml
          30_configportal
            30_usecasedefinition
              large_entity_1.yaml
              large_entity_2.yaml
              large_entity_3.yaml
              third_party_endpoints.yaml
```

and provide the content for the `.yaml` files under `files/hull-vidispine-addon/installation/endpoints`.

The crucial aspects of using this feature are:

- the files used for sourcing data must be stored beneath `files/hull-vidispine-addon/installation/endpoints`, otherwise they will not be detected and picked up
- if a complete file is to be provided for an `endpoint`/`subresource`/`entity` it must have the objects key as the filename, end with `.yaml` and be placed in the correct folder matching the tree structure:

  - endpoint:
    - store at `files/hull-vidispine-addon/installation/endpoints/<endpoint_key>.yaml`
    - example: `files/hull-vidispine-addon/installation/endpoints/20_authservice.yaml`
  - subresource:
    - store at `files/hull-vidispine-addon/installation/endpoints/<endpoint_key>/<subresource_key>.yaml`
    - example: `files/hull-vidispine-addon/installation/endpoints/20_authservice/20_clients.yaml`
  - entity:
    - store at `files/hull-vidispine-addon/installation/endpoints/<endpoint_key>/<subresource_key>/<entity_key>.yaml`
    - example: `files/hull-vidispine-addon/installation/endpoints/30_configportal/30_usecasedefinitions/third_party_endpoints.yaml`

When the `hull-vidispine-addon` detects the presence of files and folders matching the above specification, the found files contents are merged with the `installation` section within `values.yaml`.

To wrap up the example, the contents of 

`files/hull-vidispine-addon/installation/endpoints/20_authservice.yaml` 

could for example be:

```yaml
_DEFAULTS_:
  register: true
  putUriExcludeIdentifier: true
  overwriteExisting: true
  config:
    requireClientSecret: false
    requireConsent: false
    allowRememberConsent: true
    allowAccessTokensViaBrowser: true
    allowOfflineAccess: true
    alwaysIncludeUserClaimsInIdToken: true
    identityTokenLifetime: 300
    accessTokenLifetime: 3600
    authorizationCodeLifetime: 300
    absoluteRefreshTokenLifetime: 2592000
    slidingRefreshTokenLifetime: 1296000
    refreshTokenUsage: 1
    updateAccessTokenClaimsOnRefresh: false
    refreshTokenExpiration: 1
    accessTokenType: 0
    includeJwtId: false
    alwaysSendClientClaims: true
    clientClaimsPrefix: ""
entities:
  camunda_broker_api:
    identifier: _HT*hull.config.specific.components.camunda-broker-api.auth.clientId
    config:
      clientName: Camunda Broker Client
      clientId: _HT*hull.config.specific.components.camunda-broker-api.auth.clientId
      clientSecrets:
        - description: Camunda Broker Client
          value: _HT*hull.config.specific.components.camunda-broker-api.auth.clientSecret
      allowedGrantTypes:
        - client_credentials
        - authorization_code
      allowedScopes:
        - api1
        - configportalscope
        - openid
        - profile
      claims:
        - value: CP_API_CONSUMER
          type: client_role
        - value: admin
          type: camunda_user
        - value: camunda-admin
          type: camunda_role
      redirectUris:
        _HULL_TRANSFORMATION_:
          NAME: hull.vidispine.addon.producturis
          APPENDS:
            - /signin-oidc
  camunda_deployment_api:
    identifier: _HT*hull.config.specific.components.camunda-deployment-api.auth.clientId
    config:
      clientName: Camunda Deployment Client
      clientId: _HT*hull.config.specific.components.camunda-deployment-api.auth.clientId
      clientSecrets:
        - description: Camunda Deployment Client
          value: _HT*hull.config.specific.components.camunda-deployment-api.auth.clientSecret
      allowedGrantTypes:
        - client_credentials
      allowedScopes:
        - api1
        - identityscope
        - configportalscope
      claims:
        - value: CP_API_CONSUMER
          type: client_role
        - value: admin
          type: camunda_user
        - value: camunda-admin
          type: camunda_role
  conditional_workflow_api:
    identifier: _HT*hull.config.specific.components.conditional-workflow-api.auth.clientId
    config:
      clientName: Conditional Workflow Service Client
      clientId: _HT*hull.config.specific.components.conditional-workflow-api.auth.clientId
      clientSecrets:
        - description: Conditional Workflow Service
          value: _HT*hull.config.specific.components.conditional-workflow-api.auth.clientSecret
      allowedGrantTypes:
        - client_credentials
        - authorization_code
      allowedScopes:
        - identityscope
        - configportalscope
        - openid
        - profile
        - api1
      claims:
        - value: CP_API_CONSUMER
          type: client_role
      redirectUris:
        _HULL_TRANSFORMATION_:
          NAME: hull.vidispine.addon.producturis
          APPENDS:
            - /signin-oidc
  ...
```
and the contents of:

`files/hull-vidispine-addon/installation/endpoints/20_authservice/20_clients/third_party_endpoints.yaml` 

may look like this:

```yaml
identifier: "ba6cd8b3-f2f2-49bc-af52-88c9c51ef752"
config:
  Guid: "ba6cd8b3-f2f2-49bc-af52-88c9c51ef752"
  UseCaseGroupOrderNo: 3
  UseCaseGroupName: "External Interfaces"
  OrderNo: 3
  ProductGuid:
  -  "1e5dde6f-8a54-4bf4-827e-cf898d2e0888"
  Json: |
    _HT!
      '{
        "Actions": [
          {
            "IsEnabled": true,
            "Name": "Edit",
            "OrderNo": 1,
            "TooltipMessage": "Edit this item",
            "Type": "edit"
          }
        ],
        "AllowMultipleConfig": false,
        "Fields": [
          {
            "DefaultConfigValue": 3000,
            "DisplayName": "Vidispine : Job Checking Interval",
            "IsEnvironmentDependent": false,
            "IsRequired": true,
            "Maximum": 60000,
            "Minimum": 3000,
            "Name": "PF_Vidispine_JobCheckingInterval",
            "Placeholder": "Enter the time between two iterations of checking a job status.",
            "TooltipMessage": "For jobs that are started in vidispine, this defines the time in milliseconds between two iterations of checking a job status.",
            "Type": "Number_Basic"
          },
          {
            "DefaultConfigValue": [
              {
                "EndpointType": "PF_PROXYURLPREFIX",
                "IsActive": true,
                "Label": "Proxy Url Prefix",
                "Name": "Proxy Url Prefix",
                "Password": null,
                "Url": "",
                "User": null
              }
            ],
            "DisplayName": "Proxy Url Prefix",
            "Input": [
              {
                "DefaultValue": "Proxy url Prefix",
                "DisplayName": "Name",
                "IsRequired": true,
                "Name": "Name",
                "Placeholder": "Enter Name of the proxy url endpoint",
                "TooltipMessage": "The name of the proxy url endpoint.",
                "Type": "String_Name"
              },
              {
                "DefaultValue": "",
                "DisplayName": "Endpoint URL",
                "IsRequired": true,
                "Name": "Url",
                "Pattern": "https?://.+",
                "Placeholder": "Enter the http uri for the proxy url prefix...",
                "TooltipMessage": "The endpoint uri of the proxy url prefix.",
                "Type": "String_Url"
              },
              {
                "DisplayName": "Credentials",
                "InputProperties": {
                  "Password": "Password",
                  "Username": "User"
                },
                "IsRequired": false,
                "Name": "user",
                "Type": "CustomInput_Credential"
              },
              {
                "DisplayName": "Status",
                "Name": "IsActive",
                "Type": "Toggle_Status"
              }
            ],
            "IsRequired": true,
            "Name": "PF_ProxyUrlPrefix_Endpoint",
            "SystemEndpoint_Type": "PF_PROXYURLPREFIX",
            "Type": "CustomInput_SystemEndpoint"
          },
          {
            "DefaultConfigValue": [
              {
                "EndpointType": "PF_RABBITMQ",
                "IsActive": true,
                "Label": "RabbitMQ Service",
                "Name": "RabbitMQ Service",
                "Password": "VPMS_Platform",
                "Url": "{{ (index . "$").Values.hull.config.general.data.endpoints.rabbitmq.uri.amq }}",
                "User": "VPMS_Platform"
              }
            ],
            "DisplayName": "RabbitMQ Service",
            "Input": [
              {
                "DefaultValue": "RabbitMQ Service",
                "DisplayName": "Name",
                "IsRequired": true,
                "Name": "Name",
                "Placeholder": "Enter Name of the RabbitMQ Service endpoint",
                "TooltipMessage": "The name of the RabbitMQ Service endpoint.",
                "Type": "String_Name"
              },
              {
                "DefaultValue": "{{ (index . "$").Values.hull.config.general.data.endpoints.rabbitmq.uri.amq }}",
                "DisplayName": "Endpoint URL",
                "IsRequired": true,
                "Name": "Url",
                "Pattern": "https?://.+",
                "Placeholder": "Enter the http uri for the RabbitMQ Service...",
                "TooltipMessage": "The endpoint uri of the RabbitMQ Service (Changes take effect after respective services restarted).",
                "Type": "String_Url"
              },
              {
                "DisplayName": "Credentials",
                "InputProperties": {
                  "Password": "Password",
                  "Username": "User"
                },
                "IsRequired": true,
                "Name": "user",
                "Type": "CustomInput_Credential"
              },
              {
                "DisplayName": "Status",
                "Name": "IsActive",
                "Type": "Toggle_Status"
              }
            ],
            "IsRequired": true,
            "Name": "PF_RabbitMQ_Endpoint",
            "SystemEndpoint_Type": "PF_RABBITMQ",
            "Type": "CustomInput_SystemEndpoint"
          },
          {
            "DefaultConfigValue": [
              {
                "EndpointType": "PF_ELASTICSEARCH",
                "IsActive": true,
                "Label": "ElasticSearch Service",
                "Name": "ElasticSearch Service",
                "Password": null,
                "Url": "{{ (index . "$").Values.hull.config.general.data.endpoints.opensearch.uri.api }}",
                "User": null
              }
            ],
            "DisplayName": "ElasticSearch Service",
            "Input": [
              {
                "DefaultValue": "ElasticSearch Service",
                "DisplayName": "Name",
                "IsRequired": true,
                "Name": "Name",
                "Placeholder": "Enter Name of the ElasticSearch Service endpoint",
                "TooltipMessage": "The name of the ElasticSearch Service endpoint.",
                "Type": "String_Name"
              },
              {
                "DefaultValue": "{{ (index . "$").Values.hull.config.general.data.endpoints.opensearch.uri.api }}",
                "DisplayName": "Endpoint URL",
                "IsRequired": true,
                "Name": "Url",
                "Pattern": "https?://.+",
                "Placeholder": "Enter the http uri for the ElasticSearch Service...",
                "TooltipMessage": "The endpoint uri of the ElasticSearch Service.",
                "Type": "String_Url"
              },
              {
                "DisplayName": "Credentials",
                "InputProperties": {
                  "Password": "Password",
                  "Username": "User"
                },
                "IsRequired": false,
                "Name": "user",
                "Type": "CustomInput_Credential"
              },
              {
                "DisplayName": "Status",
                "Name": "IsActive",
                "Type": "Toggle_Status"
              }
            ],
            "IsRequired": true,
            "Name": "PF_ElasticSearch_Endpoint",
            "SystemEndpoint_Type": "PF_ELASTICSEARCH",
            "Type": "CustomInput_SystemEndpoint"
          },
          {
            "DefaultConfigValue": [
              {
                "EndpointType": "PF_BPMN_ENGINE",
                "IsActive": true,
                "Label": "Camunda Default",
                "Name": "Camunda Default",
                "Password": "demo",
                "Url": "{{ (index . "$").Values.hull.config.general.data.endpoints.camunda.uri.api }}",
                "User": "demo"
              }
            ],
            "DisplayName": "Camunda BPMN Engine",
            "Input": [
              {
                "DefaultValue": "Camunda BPMN Engine",
                "DisplayName": "Name",
                "IsRequired": true,
                "Name": "Name",
                "Placeholder": "Enter Name of the Camunda API endpoint...",
                "TooltipMessage": "The endpoint of the Camunda BPMN engine.",
                "Type": "String_Name"
              },
              {
                "DefaultValue": "{{ (index . "$").Values.hull.config.general.data.endpoints.camunda.uri.api }}",
                "DisplayName": "Endpoint URL",
                "IsRequired": true,
                "Name": "Url",
                "Pattern": "https?://.+",
                "Placeholder": "Enter the Camunda BPMN Engine endpoint...",
                "TooltipMessage": "The endpoint uri of the Camunda BPMN Engine.",
                "Type": "String_Url"
              },
              {
                "DisplayName": "Credentials",
                "InputProperties": {
                  "Password": "Password",
                  "Username": "User"
                },
                "IsRequired": false,
                "Name": "user",
                "Type": "CustomInput_Credential"
              },
              {
                "DisplayName": "Status",
                "Name": "IsActive",
                "Type": "Toggle_Status"
              }
            ],
            "IsRequired": true,
            "Name": "PF_CamundaBpmnEngine_Endpoint",
            "SystemEndpoint_Type": "PF_BPMN_ENGINE",
            "Type": "CustomInput_SystemEndpoint"
          },
          {
            "DefaultConfigValue": [
              {
                "EndpointType": "PF_DMN_ENGINE",
                "IsActive": true,
                "Label": "Camunda Default",
                "Name": "Camunda Default",
                "Password": "demo",
                "Url": "{{ (index . "$").Values.hull.config.general.data.endpoints.opensearch.uri.api }}",
                "User": "demo"
              }
            ],
            "DisplayName": "Camunda DMN Engine",
            "Input": [
              {
                "DefaultValue": "Camunda DMN Engine",
                "DisplayName": "Name",
                "IsRequired": true,
                "Name": "Name",
                "Placeholder": "Enter Name of the Camunda API",
                "TooltipMessage": "Enter Name of the Camunda API",
                "Type": "String_Name"
              },
              {
                "DefaultValue": "{{ (index . "$").Values.hull.config.general.data.endpoints.opensearch.uri.api }}",
                "DisplayName": "Endpoint URL",
                "IsRequired": true,
                "Name": "Url",
                "Pattern": "https?://.+",
                "Placeholder": "Enter the Camunda DMN Engine endpoint...",
                "TooltipMessage": "The endpoint uri of the Camunda DMN Engine.",
                "Type": "String_Url"
              },
              {
                "DisplayName": "Credentials",
                "InputProperties": {
                  "Password": "Password",
                  "Username": "User"
                },
                "IsRequired": false,
                "Name": "user",
                "Type": "CustomInput_Credential"
              },
              {
                "DisplayName": "Status",
                "Name": "IsActive",
                "Type": "Toggle_Status"
              }
            ],
            "IsRequired": true,
            "Name": "PF_CamundaDmnEngine_Endpoint",
            "SystemEndpoint_Type": "PF_DMN_ENGINE",
            "Type": "CustomInput_SystemEndpoint"
          }
        ],
        "HasDefaultConfig": true,
        "Overview": {
          "AllowToggleView": false,
          "Columns": [],
          "View": "detailed"
        }
      }'
```

### Details of the `installation.yaml referencing` sourcing approach

To work with this approach, simply put your files you want to access during installation in the `files/hull-vidispine-addon/installation/sources` folder.

Then when accessing them, you can resort to `readConfigValuesFromFiles` or `readConfigFromFile` to include the file contents in your entities `config`. There are three basic ways available to use this feature:
- use `readConfigFromFile` and provide the file name as a value to set the value of `config` to the files content.
- use `readConfigValuesFromFiles` and provide no `key` on the dictionary entries to map the whole file contents to a top-level JSON key in the `config`. 
The `config` here is standard JSON and may have more keys defined directly under `config` and the file contents are merged to the specified target keys, see license example following.
- use `readConfigValuesFromFiles` and provide a `key` on the dictionary entries to map values from keys in the JSON file contents to a top-level JSON key in the `config`. This necessitates that the imported file is a valid JSON file, otherwise the mapping does not work. See license example below where from the source `license.json` file the keys `license` and `version` are mapped to their counterparts in the `config` respectively.


```yaml
60_productcomponents:
  _DEFAULTS_:
    putUriExcludeIdentifier: false
    register: true
    remove: false
  apiPath: v2/ProductComponent
  identifierQueryParam: Name
  typeDescription: ProductComponent
  entities:
    license:
      identifier: 7a9daa5f-3eee-0897-7677-f92c73d55781
      config:
        name: Platform.CoreServices
        guid: 7a9daa5f-3eee-0897-7677-f92c73d55781
        productGuid: 1e5dde6f-8a54-4bf4-827e-cf898d2e0888
        version:
        license:
      register: true
      overwriteExisting: true
      readConfigValuesFromFiles:
        license:
          path: license.json
          key: license
        version:
          path: license.json
          key: version
```

## The `library` functions

The library functions in `/templates/_library.tpl` are especially provided to allow minimal effort Helm Chart creation for recurring configuration scenarios of Vidispine products. Some of the methods rely heavily on preconditions which must be met so that they can be used effectively.

The following functions are defined:

### hull.vidispine.addon.library.safeGetString

Parameters:

_DICTIONARY_: A dictionary to traverse
_KEY_: The key in dot-notation within _DICTIONARY_whose value should be retrieved and converted to a string

Usage:

Simple function to retrieve a value for a key provided in dot-notation from a given dictionary. 
If the key exists and it's value is neither a dictionary, array or null it is converted to string and returned. In all other cases the nothing/empty string is returned.

Example:

For _DICTIONARY_ `$letters` with:

```
a: 
  b:
    c:
      d: helloD
  e:
    f:
       g: helloG    
```

the result will be for _KEY_:
- `a.b.c.d` --> "helloD"
- `a.b.c.c` --> ""
- `a.e.f` --> ""
- `a.e.f.g` --> "helloG"
- `a.e.f.h` --> ""

### hull.vidispine.addon.library.get.endpoint.uri.exists

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_KEY_: The key denoting the endpoint which may contain the _URI_ (works but obsolete, use _ENDPOINT_ instead)
_ENDPOINT_: The key denoting the endpoint which may contain the _URI_
_URI_: The particular uri to get

Usage:

This function works with `hull.config.general.data.endpoints` section to return whether a particular URI is defined for a given endpoint named with _ENDPOINT_. The function furthermore checks for whether the _URI_ is defined with a suffix of `Internal` or without it, if at least one of these _URI_'s is defined and has a value, literal string `true` is returned, if not literal string `false`.

Example:

For `hull.config.general.data.endpoints`:

```
endpoints:
  vidicore:
    auth:
      basic:
        adminPassword: admin
        adminUsername: admin
    uri:
      api: https://prept1-vidiflow.s4m.de/API
      apiInternal: http://vidicore-vidicore.preptest1:31060/API
      apinoauthInternal: http://vidicore-vidicore.preptest1:31060/APInoauth
      logReport: http://vidicore-vidicore.preptest1:31060/LogReport
```

the following _ENDPOINT_ and _URI_ combinations yield:

- _ENDPOINT_="vidicore" _URI_="api" --> "true"
- _ENDPOINT_="vidicore" _URI_="apinoauth" --> "true"
- _ENDPOINT_="vidicore" _URI_="logReport" --> "true"
- _ENDPOINT_="vidicore" _URI_="crashReport" --> "false"
- _ENDPOINT_="vidividividi" _URI_="api" --> "false"

### hull.vidispine.addon.library.get.endpoint.uri.info

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_ENDPOINT_: The key denoting the endpoint which may contain the _URI_
_URI_: The particular uri to get
_INFO_: The kind of information to get. Allowed values: uri|host|hostname|netloc|path|scheme|port|base

Usage:

This function works with `hull.config.general.data.endpoints` section to return a particular aspect of an _URI_ which is defined for a given endpoint named with _ENDPOINT_. The function furthermore checks for whether the _URI_ is defined with a suffix of `Internal` or without it. If an `Internal` suffixes _URI_ exists it has precedence over an _URI_ without the suffix for the evaluation of _INFO_.

Allowed values for _INFO_:
- `uri`: return the complete URI as it is configured
- `host` or `hostname`: return the hostname (excluding port) of the URI
- `netloc`: return the hostname (with port if defined) of the URI
- `path`: returns the relative path of the URI
- `scheme`: return the scheme of the URI
- `port`: return the port of the URI. If not explicitly set returns 80 for scheme 'http' and 443 for scheme 'https'
- `base`: return the scheme plus hostname and port (excluding any subpaths)


Example:

For `hull.config.general.data.endpoints`:

```
endpoints:
  vidicore:
    auth:
      basic:
        adminPassword: admin
        adminUsername: admin
    uri:
      api: https://prept1-vidiflow.s4m.de/API
      apiInternal: http://vidicore-vidicore.preptest1:31060/API
      apinoauthInternal: http://vidicore-vidicore.preptest1:31060/APInoauth
      logReport: http://vidicore-vidicore.preptest1:31060/LogReport
```

the following _ENDPOINT_ and _URI_ combinations yield:

- _ENDPOINT_="vidicore" _URI_="api" _INFO_="uri" --> "http://vidicore-vidicore.preptest1:31060/API"
- _ENDPOINT_="vidicore" _URI_="api" _INFO_="host" --> "vidicore-vidicore.preptest1"
- _ENDPOINT_="vidicore" _URI_="api" _INFO_="hostname" --> "vidicore-vidicore.preptest1"
- _ENDPOINT_="vidicore" _URI_="api" _INFO_="netloc" --> "vidicore-vidicore.preptest1:31060"
- _ENDPOINT_="vidicore" _URI_="api" _INFO_="path" --> "/API"
- _ENDPOINT_="vidicore" _URI_="api" _INFO_="scheme" --> "http"
- _ENDPOINT_="vidicore" _URI_="api" _INFO_="port" --> "31060"
- _ENDPOINT_="vidicore" _URI_="api" _INFO_="base" --> "http://vidicore-vidicore.preptest1:31060"
- _ENDPOINT_="vidicore" _URI_="crashReport" _INFO_="uri" --> ""
- _ENDPOINT_="vidividividi" _URI_="api" _INFO_="uri" --> ""

### hull.vidispine.addon.library.get.endpoint.key

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_TYPE_: The type of the endpoint to get the concrete specificaton of. Allowed values: database|index

Usage:

This function queries for a given endpoint _TYPE_ and returns the best result. 

For _TYPE_ `database`, the value `postgres` is returned if an `endpoint` value that is not empty exists for the `postgres` endpoint.  If an `endpoint` value that is not empty exists for the `mssql` endpoint otherwise, the value `mssql` is returned. 

For _TYPE_ `index`, `opensearch` is returned if either the URI `api` or `apiInternal` is defined for an endpoint `opensearch`.

### hull.vidispine.addon.library.get.endpoint.info

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_INFO_: The kind of information to get. Allowed values: host|hostname|port|usernamesPostfix|connectionString|vhost
_TYPE_: The type of the endpoint to get the concrete specificaton of. Allowed values: database|messagebus|index
_COMPONENT_: The `component` from `hull.config.specific.components` which may be required in calulation of the returned value. Needed for some _INFO_ queries. 

Usage:

This function returns special values which are calculated on the fly from the given endpoints.
- _INFO="host" or _INFO="hostname" in combination with _TYPE_="database" returns the selected database `adresss`'s host without port
- _INFO="port" in combination with _TYPE_="database" returns the selected database `address`'s port. Can be contained in the `address` and returned as defined or if not returns defaults (1433 for `mssql` and 4532 for `postgres`)
- `usernamesPostfix` in combination with _TYPE_="database" returns the value of the database endpoints `auth.basic.usernamesPostfix` if defined or empty string if not
- `connectionString` in combination with _TYPE_="database" returns the calculated value of the database connectionString as used by e.g. VidiFlow agents. Requires a _COMPONENT_ to be selected containing a `database.username` and `database.password` to embedd into the connectionString returned.
- `connectionString` in combination with _TYPE_="messagebus" returns the calculated value of the RabbitMQ connectionString as used by e.g. VidiFlow agents. This connectionString includes "username:password@" infix opposed to the `amq`/`amqInternal` URIs that don't contain credentials. Requires that an endpoint for `rabbitmq` and an `amq`/`amqInternal` URI is defined as well as `rabbitmq.auth.basic.username` and `rabbitmq.auth.basic.password`.
- `vhost` in combination with _TYPE_="messagebus" returns the vhost of the RabbitMQ connectionString. Requires that an endpoint for `rabbitmq` and an `amq`/`amqInternal` URI is defined.

### hull.vidispine.addon.library.auth.secret.data

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_EDNPOINTS_: The endpoints for which `auth` data is to be included as a comma-separated list. Can be either resolvable types (`database` and `index`) or an exact key name found in the endpoints.

Usage:

The purpose of this function is to create the data section for a unique secret named `auth` for the Helm Chart which contains all relevant sensitive data that is general and not specific to a particular component (so excluding components database credentials etc). However the exception is that all OAuth relevant clientIds and clientSecrets are added as well (so that hull-install can use them if needed). For storing each components other sensitive data (database connection) exists a dedicated secret named same as the component.

The `auth` secret contains:
1. all key-value pairs which are defined in an `auth` subkey of an endpoint which is in the list of _ENDPOINTS_. The script iterates all endpoints and if the have an `auth` subkey the data is added to the secret by creating an uppercase secret data key name unique to the key-value pair. The secret data key name creation follows this rule: `AUTH_<ENDPOINT>_<AUTHKIND>_<AUTHKEY` where the <ENDPOINT> is either `database`, `index` or a concrete endpoints name, the <AUTHKIND> is the subkey of `auth` (`basic` or `token`) and <AUTHKEY> is the actual key. 
2. all `clientId` and `clientSecret` values defined for all components in the form `CLIENT_<COMPONENT>_ID` and `CLIENT_<COMPONENT>_SECRET`.
3. authservice specific OAuth clients for compatibility and direct usage within the hull-install job. For this - if defined - the values for `endpoints.authservice.auth.token.installationClientId` and `endpoints.authservice.auth.token.installationClientSecret` are stored as keys `CLIENT_AUTHSERVICE_INSTALLATION_ID` and `CLIENT_AUTHSERVICE_INSTALLATION_SECRET` respectively.
4. configportal specific OAuth clients for compatibility and direct usage within the hull-install job. For this - if defined - the values for `endpoints.configportal.auth.token.installationClientId` and `endpoints.authservice.auth.token.installationClientSecret` are stored as keys `CLIENT_CONFIGPORTAL_INSTALLATION_ID` and `CLIENT_CONFIGPORTAL_INSTALLATION_SECRET` respectively.

### hull.vidispine.addon.library.component.secret.data

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_COMPONENT_: The component to create the secret data for

Usage:

With calling this function the data section for a component specific secret is created. The secret contains automatically the following data keys and contents:
1. First it traverses the _COMPONENT_ in `hull.config.specific.components` and adds all `mounts.secret`'s contents defined to the volume. It also adds all Secrets defined as physical files which are stored under the `files/_COMPONENT_/mounts/secret` folders.
2. Database connection information is added from the components `database` specification if it exists, the keys `AUTH_BASIC_DATABASE_NAME`, `AUTH_BASIC_DATABASE_USERNAME` and `AUTH_BASIC_DATABASE_PASSWORD` are added with their defined values . Furthermore a key `database-connectionString` is added which contains a ready to use database connectionString including credential data.
3. If an `amq` or `amqInternal` endpoint is specified, the key `rabbitmq-connectionString` is added and the RabbitMQ connectionstring is assembled as its value

### hull.vidispine.addon.library.component.configmap.data

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_COMPONENT_: The component to create the ConfigMap data for


Usage:

To add all defined ConfigMaps for a _COMPONENT_, this function traverses the _COMPONENT_ in `hull.config.specific.components` and adds all `mounts.configmap`'s contents defined to the volume. It also adds all ConfigMaps defined as physical files which are stored under the `files/_COMPONENT_/mounts/configmap` folders.

### hull.vidispine.addon.library.component.ingress.rules

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_COMPONENTS_: The `component`s from `hull.config.specific.components` as a comma-separated list. The input values need to be lowercase seperated with '-' (kebapcase) and are converted to the URI keys by making them camelCase.
_ENDPOINT_: The endpoint for which the URIs created from _COMPONENTS_ are all defined
_PORTNAME_: The name of the port that is targeted, defaults to "http" if not set
_SERVICENAME_: The name of the service that is targeted

Usage:

With this function it is possible to render ingress rules based on minimal input. Given that one or more URIs are given in kebap-case notation as _COMPONENTS_, and they are specified under the given _ENDPOINT_ in `hull.config.general.data.endpoints`, for each of them an ingress rule is created with the ingress host set to the hostname contained in the resolved _COMPONENT_ URI and one path for the _COMPONENT_ URI's subpath. The targeted service is defined by _SERVICENAME_ and _PORTNAME_. Note that for ingresses, only set URIs that exclude the `Internal` suffix are considered because ingresses deal with traffic incoming to the cluster.

Example:

Given `hull.config.general.data.endpoints`:

```
endpoints:
  vidicore:
    auth:
      basic:
        adminPassword: admin
        adminUsername: admin
    uri:
      api: https://prept1-vidiflow.s4m.de/API
      apiInternal: http://vidicore-vidicore.preptest1:31060/API
      apinoauthInternal: http://vidicore-vidicore.preptest1:31060/APInoauth
      logReport: http://vidicore-vidicore.preptest1:31060/LogReport
```

and _COMPONENTS_="api,log-report", _ENDPOINT_="vidicore", _SERVICENAME_="vidicore" this creates two ingress rules where host is 'prept1-vidiflow.s4m.de' and the targeted service/port is vidicore/http for all three. The paths are however different with '/API' and '/LogReport'.

### hull.vidispine.addon.library.component.job.database

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_COMPONENT_: The `component` to create a database job for
_TYPE_: The type of Job. Allowed values: create|reset
Usage:

This function full renders job objects that either create or reset a database defined for _COMPONENT_. The container used for these database operations is the 'vpms/dbtools' and the tag to use is given in the `hull.config.specific.tags.dbTools` field. In order to work correctly, the following environment variables are provided to each 'vpms/dbtools' instance executed:
- DBHOST: retrieved from the database endpoints (`postgres` or `mssql`) `uri.address` field
- DBPORT: retrieved from the database endpoints (`postgres` or `mssql`) `uri.address` field
- DBTYPE: `postgres` or `mssql`, determined by hull.vidispine.addon.library.get.endpoint.key function
- DBADMINUSER: retrieved from key AUTH_BASIC_DATABASE_ADMINUSERNAME from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
- DBUSERPOSTFIX: retrieved from key AUTH_BASIC_DATABASE_USERNAMESPOSTFIX from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
- DBADMINPASSWORD: retrieved from key AUTH_BASIC_DATABASE_ADMINPASSWORD from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
- DBNAME: retrieved from key AUTH_BASIC_DATABASE_NAME from _COMPONENT_ secret (see 'hull.vidispine.addon.library.component.secret.data')
- DBUSER: retrieved from key AUTH_BASIC_DATABASE_USERNAME from _COMPONENT_ secret (see 'hull.vidispine.addon.library.component.secret.data')
- DBPASSWORD: retrieved from key AUTH_BASIC_DATABASE_PASSWORD from _COMPONENT_ secret (see 'hull.vidispine.addon.library.component.secret.data')

For _TYPE_=create the following is happening:
1. Check if database server can be reached
2. Verify the database with name DBNAME is accessible for DBUSER. If DBADMINUSER and DBADMINPASSWORD is given, the DBNAME and DBUSER are created in the database so that database with name DBNAME is also accessible for DBUSER. If no DBADMINUSER and DBADMINPASSWORD is given, only successful access for DBUSER to DBNAME is checked.

For _TYPE_=delete the following is happening:
1. Check if database server can be reached
2. Reset the database with DBNAME.

### hull.vidispine.addon.library.component.pod.volumes

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_COMPONENT_: The `component` to create a volume section for
need to be lowercase seperated with '-' (kebapcase) and are converted to the URI keys by making them camelCase.
_SECRETS_: The additional Secrets to add to the volumes as comma-seperated list
_CONFIGMAPS_: The additional configMap volumes to add to the volumes as comma-seperated list
_EMPTYDIRS_: The additional emptyDir volumes to add to the volumes as comma-seperated list
_PVCS_:  The additional persistentVolumeClaim volumes to add to the volumes as comma-seperated list

Usage:

This function renders a pods volumes section based on the arguments and rest of the charts configuration:
First it traverses the _COMPONENT_ in `hull.config.specific.components` and adds all `mounts.secret`'s and `mounts.configmap`'s names as references to the volumes secret and configMap volumes. It also adds all Secrets and ConfigMaps names as references for all defined physical files which are stored under the `files/_COMPONENT_/mounts/secret` and `files/_COMPONENT_/mounts/configmap` folders. Then it adds all addional secret's, configMap's, emptyDir's and persistentVolumeClaim's static reference names provided as additional arguments where the name of the reference is the full object name which is being referenced.

### hull.vidispine.addon.library.component.pod.env

Parameters:

_PARENT_CONTEXT_: The Helm charts global context
_COMPONENT_: The `component` to create an env section for

Usage:

This function renders the `env` section of a pod in a standardized form that is used by VidiFlow agents mostly. Each VidiFlow agent expects a standard number of environment variables to work as demanded, those are always:
- DBUSERPOSTFIX: retrieved from key AUTH_BASIC_DATABASE_USERNAMESPOSTFIX from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
- DBADMINUSER: retrieved from key AUTH_BASIC_DATABASE_ADMINUSERNAME from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
- DBADMINPASSWORD: retrieved from key AUTH_BASIC_DATABASE_ADMINPASSWORD from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')

Additional env vars are added if preconditions are met:
- if an _TYPE_ 'index' endpoint is configured(see hull.vidispine.addon.library.get.endpoint.key):
  - ELASTICSEARCH__USERNAME: retrieved from key AUTH_BASIC_INDEX_USERNAME from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
  - ELASTICSEARCH__PASSWORD: retrieved from key AUTH_BASIC_INDEX_PASSWORD from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
- if for the _COMPONENT_ the `auth` block exists with `clientId` and `clientSecret`:
  - CLIENTSECRET__CLIENTID: retrieved from key CLIENT_<_COMPONENT_>_ID from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
  - CLIENTSECRET__CLIENTSECRET: retrieved from key CLIENT_<_COMPONENT_>_SECRET from _COMPONENT_-auth secret (see 'hull.vidispine.addon.library.auth.secret.data')
- if for the _COMPONENT_ the `database` block exists:
  - CONNECTIONSTRINGS__<database.connectionStringEnvVarSuffix>: retrieved from key database-connectionString from _COMPONENT_ secret (see 'hull.vidispine.addon.library.component.secret.data')
- if an `amq` or `amqInternal` endpoint is defined for endpoint `rabbitmq`:
  - ENDPOINTS__RABBITMQCONNECTIONSTRING: retrieved from key rabbitmq-connectionString from _COMPONENT_ secret (see 'hull.vidispine.addon.library.component.secret.data')
