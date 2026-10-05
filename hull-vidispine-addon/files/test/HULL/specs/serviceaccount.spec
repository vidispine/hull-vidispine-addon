# ServiceAccount

Test creation of objects and features.

* Prepare default test case for kind "ServiceAccount"

## Render and Validate
* Render
* Expected number of "7" objects were rendered
* Validate

## Metadata
* Check basic metadata functionality

## Hooks
* Render
* Test object "release-name-hull-test-default" of kind "ServiceAccount" does not exist

* Set test object to "release-name-hull-test-hull-install"
* Test Object has key "metadata§annotations§safe" with value "pre-install,pre-upgrade"
* Test Object has key "metadata§annotations§safe-weight" with value "-100"
* Test Object has key "metadata§annotations§safe-delete-policy" with value "before-hook-creation"

## Default ServiceAccount with createDefaultRbacTriplet
* Prepare default test case for kind "ServiceAccount" including suites "createdefaultrbactriplet"
* Render
* Set test object to "release-name-hull-test-default"
* Test Object does not have key "metadata§annotations§helm.sh/hook"
* Test Object does not have key "metadata§annotations§helm.sh/hook-weight"
* Test Object does not have key "metadata§annotations§helm.sh/hook-delete-policy"
* Test Object does not have key "metadata§annotations§safe"
* Test Object does not have key "metadata§annotations§safe-weight"
* Test Object does not have key "metadata§annotations§safe-delete-policy"

## Legacy
* Prepare default test case for kind "ServiceAccount" including suites "legacyserviceaccounthooks"
* Fail to render the templates for values file "values.hull.yaml" to test execution folder because error contains "HULL failed with error (@Values.hull.objects.serviceaccount.default.annotations) The 'default' ServiceAccount has annotations but is not rendered because 'hull.config.general.createDefaultRbacTriplet' is false."

* Prepare default test case for kind "ServiceAccount" including suites "legacyserviceaccounthooks,createdefaultrbactriplet"
* Render

* Set test object to "release-name-hull-test-default"
* Test Object has key "metadata§annotations§safe" with value "pre-install,pre-upgrade"
* Test Object has key "metadata§annotations§safe-weight" with value "-100"
* Test Object has key "metadata§annotations§safe-delete-policy" with value "before-hook-creation"


___


* Clean the test execution folder