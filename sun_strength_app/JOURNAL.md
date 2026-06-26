# Daily log
## 2026-06-16
- Fixed issues in _getAutocompleteSuggestions() by asking Google.  All problems were related to JSObect class definitions, which I don't really understand.  It is all about a Flutter "layer" and a "JavaScript" layer, and I don't understand fundamentally how these work.
-  Made a lot of progress, but now when I enter something for autocomplete, I am getting this in the console: Error fetching autocomplete predictions: TypeError: null: type 'Null' is not a subtype of type 'JSArray<Object?>'

## 2026-06-25
- Trying to get autocomplete working.  Making a big change in approach to JSInterop.  Now, as soon as I get a response, I am using .dartify() to recursively convert all JS obects to native Dart objects.  Then, I can just code like normal.
- Fixed _getLocation blah blah but still working on _getLatLngforLocation or whatever

# Future work
## Accomodate legitimate null possibilities
In location_selector_route.dart, there are some functions using the Google Places API that return variables that my code allows to be null.  Currently, if they are null, the function simply returns null, but I do not actually do anything about this is the app.  In other words, if it is actually possible, I need to tell the user something.

## Google Maps API Marker
There is some API that has been deprecated.   I think it is the thing that actually creates my marker.  It shows up in the console.

## Google Maps JavaScript API error in console
I am getting a message in the console that says: js?key=AIzaSyA4jGoTQ5Gn_zW5xuXeMmb5BdYlAWG8_Bs&libraries=places:2457 Google Maps JavaScript API has been loaded directly without loading=async. This can result in suboptimal performance. For best-practice loading patterns please see https://goo.gle/js-api-loading

## Testing
I really should learn about the various types of testing possible with Flutter.  Widget testing, etc.  This would be a good thing for me to learn in general, but it would also likely make my experience developing this app much faster.

# Notes
## Testing
### Mocking (mocktail)
You don't mock thing you are trying to test.  You mock things that need to be instantiated, accessed, etc. in order to create & use the thing you are trying to test.  If you make an object, and that object needs to access some API, for instance, you could Mock the object that handles the API call.  Then you use the when(() = {}) and similar to set up how the Mocked object should respond.  That way, you can feed your object a realistic response when it tried to call the API and instead calls the Mocked API.