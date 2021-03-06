# The hull-vidispine-addon chart

This helm chart is used to provide Vidispine specific functionality to Helm charts that are built upon the HULL library.

## The hull-install and hull-configure job

The `hull-install` job is a special Kubernetes job included in this addon chart `hull-vidispine-addon.yaml` which can be enabled via configuration. It can communicate with custom APIs to create entities which are needed for the product to function fully in the given system.

Typically there are two general scenarios for installing a Vidispine product:
- installation in a Vidispine only environment (e.g. VidiNet, MediaLogger standalone) with
  - registration in Vidispine 
- installation in a Vidispine enterprise environment with
  - registration in Authentication Service
  - registration in ConfigPortal

Technically the `hull-install` job runs as a so-called Helm hook, this means that the whole installation process pauses while the `hull-install` job runs initially **before the main pods of the application start up**. Only on successful execution the remaining objects are created abd the installation itself becomes successful. 

The `hull-configure` job is the counterpart of the `hull-install` job since it is executed **after the main pods of the application have start up successfully**. It's main purpose is therefore to communicate with APIs that the product provides to apply initial configuration, the most prominent use is to add default metadata to a ConfigPortal installation that was created within the same Helm Chart. Technically it is the same process as running the `hull-isntall` job, the only difference is that it will only apply configuration of `subresources` that are tagged with `stage: post-install`. If no `stage` tag or `stage: pre-install` is given for a subresource it will be handled by the `hull-install` job.

### Execution and Configuration

The `hull-install` and `hull-configure` job runs as a PowershellCore container and executes a pre-configured Powershell script. The configuration for the script is derived from the configuration specified in `hull-vidispine-addon.values.yaml` at 

```yaml
hull:
  config:
    general:
      data:
        installation:
```
The configuration section `hull-install` has the following structure:

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `config` | Additional configuration options.<br><br>Key: <br>One of the allowed options defined in <br>`<configSpec>`<br><br>Value: <br>The configuration options value | `preScript`<br>`postScript`<br>`productUris`
| `endpoints` | Dictionary of endpoints to communicate with.<br><br>Key: <br>Key for entry in dictionary `endpoints`<br><br>Value: <br>The endpoint definition in form of a `<endpointSpec>` | `10_vidicore:`<br>`20_authservice:`<br>`30_configportal:`

#### ConfigSpec
Describes configuration options. <br>Has exclusively the following sub-fields: <br><br>`preScript`<br>`postScript`<br>`productUris`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `preScript` | A Powershell script to be executed before the installation jobs endpoints are processed. 
| `postScript` | A Powershell script to be executed after the installation jobs endpoints are processed. 
| `productUris` | Product URIs that are can be used in conjunction with the transformations that populate authentication client data such as `hull.vidispine.addon.coruris` and `hull.vidispine.addon.producturis`. <br><br>When populated the entries here will be manipulated according to the transformation and are added to the fields where the transformation is applied. <br><br>Note that this can be automatically populated by a `hull.util.transformation.tpl` from the `hull.config.general.data.endpoints` fields like in the example. | `[]` | `productUris:`<br>`-`&#160;`https://myapp`<br>`-`&#160;`https://myappalternativehost`<br><br>or<br><br>`productUris:`<br>&#160;&#160;`_HULL_TRANSFORMATION_:`<br>&#160;&#160;&#160;&#160;`NAME:`&#160;`hull.util.transformation.tpl`<br>&#160;&#160;&#160;&#160;`CONTENT:`&#160;`"`<br>&#160;&#160;&#160;&#160;&#160;&#160;`[`<br>&#160;&#160;&#160;&#160;&#160;&#160;`{{-`&#160;`(index`&#160;`.`&#160;`\"PARENT\").Values.hull.config.general.data.endpoints.configportal.uri.api`&#160;`-}},`<br>&#160;&#160;&#160;&#160;&#160;&#160;`{{-`&#160;`(index`&#160;`.`&#160;`\"PARENT\").Values.hull.config.general.data.endpoints.configportal.uri.ui`&#160;`-}}`<br>&#160;&#160;&#160;&#160;&#160;&#160;`]"`

#### EndpointSpec
Describes an endpoint which is communicated with. <br>Has exclusively the following sub-fields: <br><br>`endpoint`<br>`auth`<br>`subresources`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `endpoint` | The HTTP/HTTPS path to the endpoint API <br><br>If this is not defined, nothing will be attempted to be written to this endpoint | | `https://vpms3testsystem.westeurope.cloudapp.azure.com:19081/Authentication/Core`<br>or<br>`http://dv-ndr-plat4.s4m.de:31060` 
| `auth` | Defines how to authenticate at the given endpoint<br><br>Has one of following keys:<br>`basic`<br>`token` |
| `auth.basic` | Defines basic authentication for connecting to API | | `env:`<br>&#160;&#160;`username:`&#160;`VIDICORE_ADMIN_USERNAME`<br>&#160;&#160;`password:`&#160;`VIDICORE_ADMIN_PASSWORD`
| `auth.basic.env.username` | Defines the environment variable that holds the username for basic auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `username` environment variable
| `auth.basic.env.password` | Defines the environment variable that holds the password for basic auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `password` environment variable
| `auth.token` | Defines token authentication for connecting to API | | `authenticationServiceEndpoint:`&#160;`"https://vpms3testsystem.westeurope.cloudapp.azure.com:19081/Authentication/Core"`<br>`env:`<br>&#160;&#160;`clientId:`&#160;`AUTHSERVICE_TOKEN_PRODUCT_CLIENT_ID`<br>&#160;&#160;`clientSecret:`&#160;`AUTHSERVICE_TOKEN_PRODUCT_CLIENT_SECRET`<br>`grantType:`&#160;`"client_credentials"`<br>`scopes:`<br>`- 'configportalscope'`<br>`- 'identityscope'`
| `endpoint.<endpointKey>.auth.authenticationServiceEndpoint` | Endpoint of AuthenticationService to get token from |
| `auth.token.env.clientId` | Defines the environment variable that holds the clientId for token auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `clientId` environment variable
| `auth.token.env.clientSecret` | Defines the environment variable that holds the clientSecret for token auth.<br><br>Note:<br>A secret must be mounted to the container which populates the `clientSecret` environment variable
| `auth.token.grantType` | Defines the grantType for the token
| `auth.token.scopes` | Defines the scopes for the token | `[]` 
| `subresources` | Dictionary of individual API routes to communicate with.<br><br>Key: <br>Key for entry in dictionary `subresources`<br><br>Value: <br>The subresource definition  in form of a `<subresourceSpec>`

#### SubresourceSpec
Describes a subresource on an endpoint which is communicated with. <br>Has exclusively the following sub-fields: <br><br>`apiPath`<br>`typeDescription`<br>`identifierQueryParam`<br>`entities`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `apiPath` | The relative path of the API on the endpoint | | `v1/Resource/ApiResource` 
| `typeDescription` |Description of the subresource 
| `identifierQueryParam` | Some APIs handle deletion of entities by DELETEing the parent resource and specifying the entity to delete in a query parameter. If the subresource handles DELETEion in that way, the query parameter to use for identifying the object needs to be stated here.
If empty or unspecified, DELETE calls will be made to the path which ends with the entities name.
 | | `"Guid"`
| `entities` | Dictionary of entities on the subresource to create, modify or delete.<br><br>Key: <br>Key for entry in dictionary `entities`<br><br>Value: <br>The entity definition in form of a `<entitySpec>` 

#### EntitySpec
Describes a particular entity on a subresource on an endpoint which is communicated with. <br>Has exclusively the following sub-fields: <br><br>`register`<br>`remove`<br>`putUriExcludeIdentifier`<br>`putInsteadOfPost`<br>`overwriteExisting`<br>`config`

| Parameter                       | Description                                                     | Defaults                 |                  Example |
| ------------------------------- | ----------------------------------------------------------------| -----------------------------| -----------------------------------------|
| `register` | If set to true, the entity will be created or modified | 
| `remove` | The entity will be DELETEd if it exists
| `putUriExcludeIdentifier` | Some APIs handle PUTting of entities by PUTing to the parent resource and specifying the entity to create in the body. If the subresource handles PUTting in that way, set this parameter to `true`. If `false` or unspecified, PUT calls will be made to the path which ends with the entities name.
| `putInsteadOfPost` | Some APIs use PUTting instead of POSTing for creation of new entities. If the subresource uses PUTting instead of POSTing, set this parameter to `true`.
| `overwriteExisting` | The default behavior is to not overwrite existing entities in case they already exist. Set this field to `true` to overwrite any existing entity.
| `config` | The free-form body of the request in YAML specification. When PUTting or POSTing to APIs the content is converted from YAML to JSON and sent with header `Content-Type: application/json` | | `Name:`&#160;`Publish`<br>`Guid:`&#160;`c9689fe0-a0e9-40d7-af82-500bba342b62`<br>`UseCaseGroupName:`&#160;`Publish`<br>`UseCaseGroupOrderNo:`&#160;`2`<br>`OrderNo:`&#160;`1`<br>`ProductGuid:`<br>`- 62e052b1-6864-4502-87dc-944be4f5d783`<br>`UseCaseType:` `dynamic`<br>`Json:`&#160;`|`<br>&#160;&#160;`{"Overview":{"AllowToggleView":false,`<br>&#160;&#160;`"View":"detailed","Columns":[]},`<br>&#160;&#160;`"Fields:"`<br>&#160;&#160;`[{"Name":"targetStorage","DisplayName":"Target`<br>&#160;&#160;`Storage","Type":"VS_Storage","IsRequired":true,`<br>&#160;&#160;`"InputProperties":{"Storage":"Storage"}},`<br>&#160;&#160;`{"Name":"userSelectableWF",`<br>&#160;&#160;`"DisplayName":"User-Selectable`&#160;`Workflows",`<br>&#160;&#160;`"Type":"Multiple_Workflow",`<br>&#160;&#160;`"IsRequired":true},`<br>&#160;&#160;`{"Name":"userSelectableMetadata",`<br>&#160;&#160;`"DisplayName":"User-Selectable Metadata",`<br>&#160;&#160;`"Type":"CustomInput_MaskedControl"}],"Actions":`<br>&#160;&#160;`[{"IsEnabled":true,"Name":"Edit","OrderNo":1,`<br>&#160;&#160;`"TooltipMessage":"Edit this Publish `<br>&#160;&#160;`Configuration","Type":"edit"},`<br>&#160;&#160;`{"IsEnabled":true,`<br>&#160;&#160;`"Name":"Workflow Designer","OrderNo":3,`<br>&#160;&#160;`"TooltipMessage":"Open Workflow Designer",`<br>&#160;&#160;`"Type":"openWorkflow",`<br>&#160;&#160;`"SystemEndpointName":"workflow designer"}]`<br>&#160;&#160;`,"AllowMultipleConfig":false}`


#### Activation and Preconfiguration
Execution of Jobs can generally be selectively enabled or not by setting the `hull.objects.job.<jobKey>.enabled` field to `true` or `false`. 

By default the `hull-install` job is not enabled but already pre-configured so that after enabling it not all information needs to be set. Pre-configuration means that:
- the container needed to run the job is defined so that it 
  - automatically loads the configuration section from `hull.config.general.data.installation`
  - mounts sensitive data as environment variables from secrets (which by default are created with the respective keys but without values). If you use the `hull-install` job in product installation you need to set the appropriate values in the secrets:
    - from `vidicore-secret` the `data` keys 
      - `adminUsername` to env var `VIDICORE_ADMIN_USERNAME` 
      - `adminPassword` to env var `VIDICORE_ADMIN_PASSWORD` 
    - from `authservice-token-secret` the `data` keys
      - `installerClientId` to env var `AUTHSERVICE_TOKEN_INSTALLER_CLIENT_ID` 
      - `installerClientSecret` to env var `AUTHSERVICE_TOKEN_INSTALLER_CLIENT_SECRET` 
      - `productClientId` to env var `AUTHSERVICE_TOKEN_PRODUCT_CLIENT_ID` 
      - `productClientSecret` to env var `AUTHSERVICE_TOKEN_PRODUCT_CLIENT_SECRET`
- typical endpoints and subresources are predefined so that only entities need to be specified. The predefined subresources for the endpoints are skipped in case the endpoint is not defined. 
  - endpoint with key `10_vidicore` is set up to do basic authentication on the vidispine endpoint defined in `hull.config.general.data.endpoints.vidicore.uri.api` using the `admin` credentials from secret `vidicore-secret`
    - subresources are configured so that creating specific entities works out of the box for them
      - key `10_metadatafields` for inserting metadatafields into Vidispine
      - key `20_metadatafieldgroups` for inserting metadatafieldgroups into Vidispine  
  - endpoint with key `20_authservice` is set up to do token authentication on the authentication service endpoint defined in `hull.config.general.data.endpoints.authservice.uri.api` using the `installer` credentials from secret `authservice-token-secret`
    - subresources are configured so that creating specific entities works out of the box for them
      - key `10_resources` for inserting scopes into authentication service
      - key `20_clients` for inserting clients into authentication service
      - key `30_roles` for inserting roles into authentication service
  - endpoint with key `30_configportal` is set up to do token authentication on the ConfigPortal  endpoint defined in `hull.config.general.data.endpoints.configportal.uri.api` using the `product` credentials from secret `authservice-token-secret`
    - subresources are configured so that creating specific entities works out of the box for them
      - key `10_product` for inserting products into ConfigPortal
      - key `20_usecasedefinitions` for inserting use-case definitions into ConfigPortal
      - key `30_usecaseconfiguration` for inserting use-case configurations into ConfigPortal
      - key `40_metadata` for inserting metadata definitions into ConfigPortal
      - key `50_roles` for inserting roles into ConfigPortal
  
Some of the keys have a numerical prefix which guarantees the order of execution is in ascending alphanumeric form. This is needed because the Go dict structure used here to store data has all keys ordered this way when retrieving them one by one. If you overwrite one of the keys you need to make sure the name including prefix is identical.