# Daily log
## 2026-06-16
- Fixed issues in _getAutocompleteSuggestions() by asking Google.  All problems were related to JSObect class definitions, which I don't really understand.  It is all about a Flutter "layer" and a "JavaScript" layer, and I don't understand fundamentally how these work.
-  Made a lot of progress, but now when I enter something for autocomplete, I am getting this in the console: Error fetching autocomplete predictions: TypeError: null: type 'Null' is not a subtype of type 'JSArray<Object?>'

# Future work
## Google Maps API Marker
There is some API that has been deprecated.   I think it is the thing that actually creates my marker.  It shows up in the console.

## Google Maps JavaScript API error in console
I am getting a message in the console that says: js?key=AIzaSyA4jGoTQ5Gn_zW5xuXeMmb5BdYlAWG8_Bs&libraries=places:2457 Google Maps JavaScript API has been loaded directly without loading=async. This can result in suboptimal performance. For best-practice loading patterns please see https://goo.gle/js-api-loading

## Testing
I really should learn about the various types of testing possible with Flutter.  Widget testing, etc.  This would be a good thing for me to learn in general, but it would also likely make my experience developing this app much faster.