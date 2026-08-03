# Daily log
## 2026-08-03
Not sure where to start, so running in debug.  I know I was starting by trying to add/fix the functionality about timezone.  Initially, the app was just using NY time all the time.  Instead, I actually want it to find the timezone for the place.  I need to test where I actually got with that.

For some reason, when I select some place in British Colombia, it is saying that there are only 364 days in the year.

Ok.  Timezone is working now.  There was a bug because I had randomly hardcoded 365 in one line of the image generation function, and that threw off the indexing.  Also, I was using a timezone database that only included "canonical" timezones and not aliases.  Now, that is fixed.

Next, I need to add a button to change the timezone display...or do I?  Maybe that just doesn't matter.  I do, however, want to add a method for the sidebar button to change default location.

Added am/pm setting.

## 2026-06-16
- Fixed issues in _getAutocompleteSuggestions() by asking Google.  All problems were related to JSObect class definitions, which I don't really understand.  It is all about a Flutter "layer" and a "JavaScript" layer, and I don't understand fundamentally how these work.
-  Made a lot of progress, but now when I enter something for autocomplete, I am getting this in the console: Error fetching autocomplete predictions: TypeError: null: type 'Null' is not a subtype of type 'JSArray<Object?>'

## 2026-06-25
- Trying to get autocomplete working.  Making a big change in approach to JSInterop.  Now, as soon as I get a response, I am using .dartify() to recursively convert all JS obects to native Dart objects.  Then, I can just code like normal.
- Fixed _getLocation blah blah but still working on _getLatLngforLocation or whatever

# Future work
## When opens to default and then click change location, marker is right but nothing appears in search bar

## Accomodate legitimate null possibilities
In location_selector_route.dart, there are some functions using the Google Places API that return variables that my code allows to be null.  Currently, if they are null, the function simply returns null, but I do not actually do anything about this is the app.  In other words, if it is actually possible, I need to tell the user something.

## Google Maps API Marker
There is some API that has been deprecated.   I think it is the thing that actually creates my marker.  It shows up in the console.

## Google Maps JavaScript API error in console
I am getting a message in the console that says: js?key=AIzaSyA4jGoTQ5Gn_zW5xuXeMmb5BdYlAWG8_Bs&libraries=places:2457 Google Maps JavaScript API has been loaded directly without loading=async. This can result in suboptimal performance. For best-practice loading patterns please see https://goo.gle/js-api-loading

## Change search bar so that, if no input, don't display anything.

## Change zooming behavior so that, when map is clicked.  Map does not automatically zoom in a bunch.

## Some locations seem to think there are only 364 days in the year.  Yellowknife, Canada in 2026 for example.

## Add a scale for the color map.

## Add a note explaining the "relative" value.

## See if there is a good way to add a "today" indicator.  If so, add a toggle for that.

## Make the pop up look better.  First, reference the above 24 vs. 12 hour display.  Just use local time (without the UTCC offset).  Move it away from the cursor a little, maybe.  Add a shadow or something.  Make it dark grey instead of black.  Or maybe make it a bit translucent.  Something to look less ugly.

## Testing
I really should learn about the various types of testing possible with Flutter.  Widget testing, etc.  This would be a good thing for me to learn in general, but it would also likely make my experience developing this app much faster.

# Notes
## Testing
### Mocking (mocktail)
You don't mock thing you are trying to test.  You mock things that need to be instantiated, accessed, etc. in order to create & use the thing you are trying to test.  If you make an object, and that object needs to access some API, for instance, you could Mock the object that handles the API call.  Then you use the when(() = {}) and similar to set up how the Mocked object should respond.  That way, you can feed your object a realistic response when it tried to call the API and instead calls the Mocked API.