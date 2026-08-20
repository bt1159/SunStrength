# Daily log
## 2026-08-18
Improved structure of CurrentIndexProvider instead of ad hoc ValueNotifier.

Issue is that, for some reason, chart doesn't use default color scheme.  I am pretty sure default is saving and loading correctly, but it is not being used by the widget.  Maybe becuase the saved value is coming through after the widget is built, but the widget isn't listening for later updates?

Color Scheme is not correctly using the saved default value.

Tweaked location of tooltip to improve readability.

Chagning year is still doing two problems.  First, the highlighted year in the picker is not updating.  Maybe I need to go back to the way it was by default without an ok button.  Also, the chart is not updating. That is my fault.  I am only changing SavedSettingsNotifier.  I don't remember if I need to manually also update CurrentChartSettings or whatever it is called.

## 2026-08-17
Fixed color scale and get it working with the inferno color scheme.

Now, 12 hour/24 hour toggle updates the y axis labels.

I mostly updated SavedSettingsNotifier to include saved color scheme, but for reason, when I re-opened the app, it didn't use the new default.

## 2026-08-14
I finally have the 2D heatmap working properly with the inferno color scheme.  I think I like it.  The blue/purple for low values takes some getting used to, but it probably makes sense.  The only problem I have right now is that the high end (>90%) doesn't really look bright enough.  It's not "scary" enough.  It should look dangerously hot...like it's scorching.  It looks like inferno tops out at a mid-pale yellow, while I want it to top out at actual white.

I have not yet converted the scale.  That might help since then you are not being distracted by a scale that shows white at the top.

I am still in the process of converting the color scale.  I just got an error saying: something about a range error.  Value was -400 but should've been between 0 and 16000.
This is almost certainly in teh color scale and when converting the Iterable<double> to colors.  Because, with 4 values per pixel, that would be 16000 length.  I have no idea why it is trying to find index -400.

## 2026-08-13
I am going to continue with the color scale.  I also want to look into what is happening with the colors themselves.  It almost looks like there is a color a bit on the yellow side of red that is the same color as one a bit on the black side of red.  The effect is a band that all looks plain red.  It looks weird.

The color bar is now done.  Next, I want to fix the width issue.  Currently, the width of the chart is hard coded in, but it is written in a confusing way that makes it extremely hard to match with the bar.  I want to instead set it up higher in the tree.  Eventually, this could become responsive.

I am currently in the middle of switching to the inferno colormap.  This is working for the 2D chart, but I still need to do it for teh color scale.  I probably have to rework to no longer be a rectangle drawn in the paint() method but rather a image like the chart.  Is there a simpler way?

ERROR: I need to NOT use replaceRange() I think.  I got an error saying that I cannot remove from a fixed-length list.

## 2026-08-06
I had just started to do a big update so that the y axis labels could be updated when the timezone changes.  But now I realize that isn't needed.  When the user changes the timezone, it will also shift the data points so that the bottom y axis point is STILL 12:00 am.  No need to change the y axis labels.

I have been working on adding the color scale.  I have the start of one, but it still needs work.  Idea: create ANOTHER custom renderwidget and renderbox.  Pass the color scale widget I just made to it as its only child.  Inside the render box, create the vertical tick lines and the labels.  That way, I can control spacing better.  In fact, if I am going to do that, I might as well just create the coloring inside my custom render box as well.  I don't need to create it as a widget and pass it in.

## 2026-08-05
I am going to continue working on updated the notifier structure.

## 2026-08-04
Today, I want to fix the tooltip appearance, especially the location.

Ok, I am doing a bit of an overhaul of the two CNs for settings.  I want the saved settings to contain default location, timezone, twelvehour, and year.  The timezone in particular does NOT need to be the local timezone of the default location.  This should be a saved setting.  I can later update the chart page so that the user can select visible timezone between local (for selected location), default timezone, and some custom value. The question is about current.  I think that current should not necessarily story the timezone associated with the current location but rather whatever the user has selected.  That way, the charting functions can ALWAYS use the current notifier to get the timezone that they should be making visible.  Updating the current location may or may not mean updating the timezone.  If the user is currently viewing local, maybe it should.  But, if the user is currently viewing a manually selected one or the default, than it should not.  I think that would work.

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
## Add a note about DST (pop up changes to always be correct local time, but y axis is solar time).

## Add somewhat of adjusting the number of y and x axis labels.  Either a setting or, even better, window size.

## Add year selection somewhere

## I need to actually build out my buttons for directly updating the default settings.

## Tweak the structure of my custom Render Objects.
Instead of passing a child to them, which requires using CustomPaint(painter: ImagePainter(image: XXXXX)), instead bury all that inside the RenderObjectWidget so that it builds the child widget itself.  OR, add a container above it that does that logic.  This will simplify the tree.

## Google Maps API Marker
There is some API that has been deprecated.   I think it is the thing that actually creates my marker.  It shows up in the console.

## Google Maps JavaScript API error in console
I am getting a message in the console that says: js?key=AIzaSyA4jGoTQ5Gn_zW5xuXeMmb5BdYlAWG8_Bs&libraries=places:2457 Google Maps JavaScript API has been loaded directly without loading=async. This can result in suboptimal performance. For best-practice loading patterns please see https://goo.gle/js-api-loading

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