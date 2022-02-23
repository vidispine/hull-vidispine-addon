# Job

Test creation of objects and features.

* Prepare default test case for kind "Job" including suites "pod"

## Render and Validate
* Render
* Expected number of "15" objects were rendered
* Validate

## Metadata
* Check basic metadata functionality

## Pod
* Render
* Check pod functionality

## Installation Job
* Render
* Set test object to "release-name-hull-test-hull-install"


* Prepare default test case for this kind including suites "pod,imagepullsecretsfromfirstregistry"
* Render

* Set test object to "release-name-hull-test-hull-install"
* Test Object has key "spec§template§spec§containers§0§image" with value "example.cr.io/vpms/powershellcore-yaml:7.0.3-ubuntu-18.04-20200928"

* Test Object has key "spec§template§spec§containers§0§volumeMounts" with array value that has "1" items
* Test Object has key "spec§template§spec§containers§0§volumeMounts§0§name" with value "installation"

* Test Object has key "spec§template§spec§volumes" with array value that has "1" items
* Test Object has key "spec§template§spec§volumes§0§name" with value "installation"

## Certificates
* Prepare default test case for this kind including suites "pod,customcacertificates"
* Render

* Set test object to "release-name-hull-test-hull-install"

* Test Object has key "spec§template§spec§containers§0§volumeMounts" with array value that has "3" items
* Test Object has key "spec§template§spec§containers§0§volumeMounts§0§name" with value "certs"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§1§name" with value "etcssl"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§2§name" with value "installation"

* Test Object has key "spec§template§spec§volumes" with array value that has "3" items
* Test Object has key "spec§template§spec§volumes§0§name" with value "certs"
* Test Object has key "spec§template§spec§volumes§1§name" with value "etcssl"
* Test Object has key "spec§template§spec§volumes§2§name" with value "installation"

* Set test object to "release-name-hull-test-custom-ca-certificates" of kind "Secret"
* Test Object has key "data§test_cert_1" with Base64 encoded value of "CERT-DATA-1"
* Test Object has key "data§test_cert_2" with Base64 encoded value of "CERT-DATA-2"
___


* Clean the test execution folder