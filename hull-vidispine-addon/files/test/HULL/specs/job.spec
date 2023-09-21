# Job

Test creation of objects and features.

* Prepare default test case for kind "Job" including suites "pod"

## Render and Validate
* Render
* Expected number of "24" objects were rendered
* Validate

## Metadata
* Check basic metadata functionality

## Pod
* Render
* Check pod functionality

## Installation Job
* Render
* Set test object to "release-name-hull-test-hull-install"
* Test Object has key "spec§template§spec§containers§0§volumeMounts" with array value that has "3" items
* Test Object has key "spec§template§spec§containers§0§volumeMounts§0§name" with value "custom-installation-files"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§1§name" with value "installation"

* Test Object has key "spec§template§spec§volumes" with array value that has "3" items
* Test Object has key "spec§template§spec§volumes§0§name" with value "custom-installation-files"
* Test Object has key "spec§template§spec§volumes§1§name" with value "installation"

## Certificates
* Prepare default test case for this kind including suites "pod,customcacertificates"
* Render

* Set test object to "release-name-hull-test-hull-install"

* Test Object has key "spec§template§spec§containers§0§volumeMounts" with array value that has "6" items
* Test Object has key "spec§template§spec§containers§0§volumeMounts§0§name" with value "certs"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§0§mountPath" with value "/usr/local/share/ca-certificates/custom-ca-certificates-test_cert_1"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§1§name" with value "certs"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§1§mountPath" with value "/usr/local/share/ca-certificates/custom-ca-certificates-test_cert_2"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§2§name" with value "custom-installation-files"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§2§mountPath" with value "/custom-installation-files"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§3§name" with value "etcssl"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§3§mountPath" with value "/etc/ssl/certs"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§4§name" with value "installation"
* Test Object has key "spec§template§spec§containers§0§volumeMounts§4§mountPath" with value "/script"

* Test Object has key "spec§template§spec§volumes" with array value that has "5" items
* Test Object has key "spec§template§spec§volumes§0§name" with value "certs"
* Test Object has key "spec§template§spec§volumes§1§name" with value "custom-installation-files"
* Test Object has key "spec§template§spec§volumes§2§name" with value "etcssl"
* Test Object has key "spec§template§spec§volumes§3§name" with value "installation"

* Set test object to "release-name-hull-test-custom-ca-certificates" of kind "Secret"
* Test Object has key "data§test_cert_1" with Base64 encoded value of "CERT-DATA-1"
* Test Object has key "data§test_cert_2" with Base64 encoded value of "CERT-DATA-2"
___


* Clean the test execution folder