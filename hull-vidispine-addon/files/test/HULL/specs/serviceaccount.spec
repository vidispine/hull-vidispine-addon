# ServiceAccount

Test creation of objects and features.

* Prepare default test case for kind "ServiceAccount"

## Render and Validate
* Render
* Expected number of "8" objects were rendered
* Validate

## Metadata
* Check basic metadata functionality

## Hooks
* Render
* Set test object to "release-name-hull-test-default"
* Test Object does not have key "metadata§annotations§helm.sh/hook"
* Test Object does not have key "metadata§annotations§helm.sh/hook-weight"
* Test Object does not have key "metadata§annotations§helm.sh/hook-delete-policy"
* Test Object does not have key "metadata§annotations§safe"
* Test Object does not have key "metadata§annotations§safe-weight"
* Test Object does not have key "metadata§annotations§safe-delete-policy"

* Set test object to "release-name-hull-test-hull-install"
* Test Object has key "metadata§annotations§safe" with value "pre-install,pre-upgrade"
* Test Object has key "metadata§annotations§safe-weight" with value "-100"
* Test Object has key "metadata§annotations§safe-delete-policy" with value "before-hook-creation"

## Legacy
* Prepare default test case for kind "ServiceAccount" including suites "legacyserviceaccounthooks"
* Render

* Set test object to "release-name-hull-test-default"
* Test Object has key "metadata§annotations§safe" with value "pre-install,pre-upgrade"
* Test Object has key "metadata§annotations§safe-weight" with value "-100"
* Test Object has key "metadata§annotations§safe-delete-policy" with value "before-hook-creation"


___


* Clean the test execution folder