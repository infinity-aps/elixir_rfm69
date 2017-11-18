## v0.2.0

This release introduces several features. There is now a struct for the Device that holds the relevant information for starting the SPI link. start_link should now be called with the struct. start_link will alias the process with the atom given in the name key of the struct, so it's possible to start more than one chip process at one time now.

When calling any of the public functions on the RFM69 module, the first parameter is the Device struct that was used to call start_link. This allows the RFM69 module to use the name key of the struct to communicate with the process, and also allows upstream libraries to more easily define a protocol for the chip functions using the structs.

Additionally, a new chip_present? function has been added that will attempt to detect whether the chip is responding using the given struct's pin and device configuration.

In some ways the library has gotten more complex because of these changes, but it solves several longstanding problems with supporting different kinds of serial devices and chips, and this should pave the way to making some simplifications in the design for developers using this package as the simplifications become clearer.

## v0.1.2

Updates `elixir_ale` dependency back to fhunleth's hex package with fix for unsetting GPIO interrupts


## v0.1.1

Initial release

This isn't a release complete with support for all the ways to interact with the RFM69 chip or even with full timeout
support or error handling. But it works. Gotta start somewhere!
