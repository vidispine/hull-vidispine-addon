# Deployment

Test Deployment features of the addon, here the JVM heap option of hull.vidispine.addon.library.java.heap.

* Prepare default test case for kind "Deployment"

## Render and Validate
* Render
* Expected number of "13" objects were rendered
* Validate

## Java heap from the memory limit
* Render

The heap is the memory limit minus the native reserve, at most 75 % of the limit.

* Set test object to "release-name-hull-test-limit_8000mi"
* Test Object has key "spec§template§spec§containers§0§env§0§value" with value "-XX:+CrashOnOutOfMemoryError -Xmx6000m -Dcom.example.site=VX"

An init container has its own resources. Without a limit it gets the default heap.

* Test Object has key "spec§template§spec§initContainers§0§env§0§value" with value "-Xmx6144m"

When the native reserve leaves less, the heap is still half of the limit.

* Set test object to "release-name-hull-test-limit_2gi"
* Test Object has key "spec§template§spec§containers§0§env§0§value" with value "-Xmx1024m"

The percentages can be changed, here to exactly half of the limit.

* Set test object to "release-name-hull-test-half_of_limit"
* Test Object has key "spec§template§spec§containers§0§env§0§value" with value "-Xmx2300m"

## Java heap without a memory limit
* Render

A memory request alone is not a limit, so the default heap applies.

* Set test object to "release-name-hull-test-no_limit"
* Test Object has key "spec§template§spec§containers§0§env§0§value" with value "-Xmx6144m"

## Java heap from explicit settings
* Render

An explicit heap wins over the limit.

* Set test object to "release-name-hull-test-explicit_heap"
* Test Object has key "spec§template§spec§containers§0§env§0§value" with value "-Xmx3072m"

A heap set in JDK_JAVA_OPTIONS of the container stays in effect, so JAVA_OPTS gets no heap option.

* Set test object to "release-name-hull-test-heap_from_environment"
* Test Object has key "spec§template§spec§containers§0§env§0§value" with value "-XX:+CrashOnOutOfMemoryError -Dcom.example.site=VX"
* Test Object has key "spec§template§spec§containers§0§env§1§value" with value "-Xmx4800m"

A maxRamPercentage keeps the behaviour from before the heap rule.

* Set test object to "release-name-hull-test-legacy_percentage"
* Test Object has key "spec§template§spec§containers§0§env§0§value" with value "-XX:MaxRAMPercentage=70"

## Java heap errors
* Fail to render the templates for values file "javaheap.heapnotbelowlimit.values.hull.yaml" to test execution folder because error contains "heap 8g is not below the memory limit 8Gi of hull.objects.deployment.main.pod.containers.main"
* Fail to render the templates for values file "javaheap.nodefaultheap.values.hull.yaml" to test execution folder because error contains "hull.objects.deployment.main.pod.containers.main has no memory limit and SETTINGS has no defaultHeap"
* Fail to render the templates for values file "javaheap.invalidlimit.values.hull.yaml" to test execution folder because error contains "hull.objects.deployment.main.pod.containers.main.resources.limits.memory: '8gb' is not a memory size such as 8Gi or 8000Mi"
