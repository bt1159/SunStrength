# Daily log
## 2026-09-21
I was trying to make a custom widget the essentially wraps an ElevatedButton and makes the greying out cleaner, but it's not worth it.
Changes to make to pop-up:
- Add small padding
- When can't fit left to right, stop panning.  In other words, when cursos is just inside of right border, pop up should be aligned on far right side.
- When can't fit below cursor, move above cursor (with the same offset, I think).
- Add TZ code.

Position looks good enough, left to right and height.  The vertical jump is weird, but I don't know what to do better.  Also, I need a better solution long term for time zone.  This works for now.

The next two tasks to tackle are to start on responsive design and also the carets for selected date.

## 2026-09-18
I fixed the bug that would happen after the location screen opens first (due to no saved settings) and then, when trying to load to next screen.

I will now add a manual button to restart app (for dev only).   Done.

Also added logic so that, when no default location exists, the first time you generate a chart, that location is saved as your default.

Also, when the current location matches default, "save as default location" is greyed out.

## 2026-09-17
Currently working on the update I made where DayDataNotifier can never be null.  Instead, it starts with a blank list.  Then, when it gets data, it overwrites that blank list.  But, if it gets new data and already had data, it gets the date of the day and month it previously had but in the current year and pulls that date's data from the new list.

Oops.  The CNP for saved settings is apparently now too low for the sidebar to reference it.
- Fixed

I have now changed the app structure so that chart screen and location screen are proper Navigator Routes rather than an IndexedStack.  I had to add some extra logic handling the case when the location screen is loaded first because there is no saved setting.

Added a button to change the size of the azimuth chart with some options.

I think I also added a button for dev only to wipe saved settings. (but see problems at the bottom.  I screwed something up.)

## 2026-09-16
I will focus now on tailoring what makes the azimuth chart disappear vs. what makes it update.  I actually can't think of anything that should make it disappear.  Perhaps I should add a button to hide it, since that always bugs me.  Like when a car stereo has a pause button but no power button.

Dependencies in Azimuth widget
Consumer<DayDataNotifier>: null = blank, not-null = use in regular widget
Selector<SavedSettingsNotifier, MyColorScheme?>: use in regular widget
Selector<SavedSettingsNotifier, bool>twelveHour: use in regular widget
Selector<CurrentChartSettingsNotifier, double>latitude: use in regular widget
Consumer<KNotifier>: use in regular widget

The only thing currently that blanks this out is if datDataNotifier is blanked.  So, I now have to go see what blanks that out and change that.
Ok.  I have now fixed the blanking out.  Changing location no longer blanks it out.

I did a bunch of refactoring to put notifiers into two files (main level and then chart level).

I fixed the problem where the gradient color in the azimuth chart didn't have good color resolution in the cool areas.

Also, I checked accuracy.  I had seen that Yellowknife, Canada (up north) said 92% for summer soltice noon, visible light, but the azimuth chart showed that it looked really low.  I checked some things, and this is correct.  The sun is about 51deg up in the sky, so just above halfway, angle-wise.  In the azimuth chart, this puts it about 2/3 of the radius away from the center.  Also, since visible light is not as impacted by airmass, even being so low, it is still 92% of solar strength.  As a note, however, the UVB in the same scenario is 55%.  That "feels" more right.

Added close button to azimuth chart.

## 2026-09-15
Did some refactoring in chart route to make the tree easier to navigate.  It might improve performance slightly, but that was not the main purpose.  It will also make it easier to tweak the layout of the chart route page, especially spacing in the column.

Ok, the spacing looks pretty good, now.  I will move on.

##2026-09-14
I started by cleaning up azimuth_widget a bit.  Particularly the paint() method.  I pulled out the paintint logic for each major pieces to make the code more readable.  Then, I have attempted to add logic that skips any labels that would overlap a preexisting label.

One problem is that the location calculated is given to the top right corner.  I need to address this somehow because it needs to depend on the angle of the break.

OOOOO, new problem.  I was looking at data somwhere in Canada and had an azimuth chart drawn.  I then switched location.  The heat map was redrawn, BUT the azimuth chart remained for Canada until I click a new day (or at least until I clicked the 2D heat map somewhere).

Ok, fixed the issue just above (blanking the azimuth chart as soon as the data above changes).  I still need to tweak the "location" of the labels.

Ok, labels work pretty well.  I accomplished what I was trying to do.  There are some improvements I could make, but these work.

I also added a button to reset chart back to default location.

I also fixed pinning the location at the top, BUT I NEED TO FIX SPACING NOW.

## 2026-09-11
Putting in place the idea I had at PT: change DayIndexNotifier to a time-zone aware datetime of the time at solar noon.  That way, everywhere will already have access to the date, without converting day index to date, and azimuth chart will have access to the timezone in order to know how to label the times.  To be clear, when I say the time at solar noon, I mean the time at index 12 * (the number of data points per hour).  Currently, that would be 48.

New plan.  I just changed DayIndexNotifier to contain the List<OrbitAndSolarData> for a single day.  Also, I adjust OrbitAndSolarData to have a property called tzDateTime that is the exact timezone-aware datetime for that data point.

Quick note: For Azimuth Chart, move selector that checks if a day is selected inside the chart widget itself.  Since the chart widget already has a consumer on DayIndexNotifier

Ok.  It looks a lot better, and the logic is much cleaner.  I really like that I just keep the TZDateTime tied to each data point, and pass the entire OrbitAndSolarData for the day to the Azimuth chart.  I do need to tweak one thing, ideally, to make the hour labels not overlap.  I will have to think creatively.  Maybe, as it iterates through each one, if its size/box overlaps a previously-made one, it just skips it.

# 2026-09-10
Starting with the hourly markers in the azimuth ribbon.

I now have the hourly dots.  Next will be labels.
Also, make the ribbon width somehow dynamic to overall image size.

## 2026-09-09
Time to fix some of the settings and default funcitonality.

Two problems with changing default year:
I click another year, the inkwell fires, but that year doesn't highlight.  Then I click ok, I see in console that the default year has changed, but the current chart settings doesn't change!
Separately, I need to make sure I understand the difference between clicking the year vs. the OK button.
- Done.

Also, removed ability to change timezone by itself.  Instead, timezone will always be automatically loaded from location.  It is too much of a hassle, and I don't understand why anyone would want to do it.

Fixed the bug about places near the equator throwing some sort of range error.  The issue was that the empirical airmass calculation I am using produces a relative solar strength slightly above 1 when elevation angle is above 88 degrees.  When viewing a location near the equator, therefore, the relative solar strength then comes out a little above 100%.  This is not technically correct, but the actual bug comes from the logic that chooses a color.  It is sent a strength value above 1 which forces it to try to pull a color from a point outside its list of colors.   I have since addd a clamp deep inside that function.  That way, any function or widget that converts strength to a number will be protected.  Tecnically, I should also update the orit calcs to change the global max number.

Fixed spacing on chart with labels

Fixed the bug where some times I only showed 364 days per year.  The issue was the way I calculated the number of years.  I started with dateTime0, which was tz aware.  Then I added a year using DateTime.add which was NOT tz aware.  When I used .difference which is timezone aware, it assumed the second datetime was UTC.  When I then rounded the different to number of days, I got 364 instead of 365.

I just started looking at the time graduated lines for the azimuth chart.  One issue is that I was extracting only the data points with a visible sun, which makes sense, but then I did not actually know the time of day for each point.  I have now adjusted the process to first marry the data with "elapsedHours" with is just index / 4 such that it is a double that represents hours in a 24 hour day.  Then, I extracted visible only points again, but now each data point is aligned with a time.  I will later be able to use that to construct the graduated time lines.

## 2026-09-05
Going to check why az chart isn't responding to change in k.
- Ok.  I see now.  Azimuth chart figures out the color for each pixel differently than the heat map of the scale.  Az chart maps the colorscheme colors to a radial distance from the center to define rings of color.  Then, when the spline points are calculated, their radial distance is equated to a color.  When I do this, however, I AM NOT taking k into account.  This works for visible light, but something about the math is different for uv-a and uv-b.
- I found a few problems.  I wasn't thinking when I first designed the azimuth chart because I simply defined the color value using a circular definition of relative strength.  That completely ignores AirMass, k value, etc.
- The biggest headache now is because I defined the color gradient of the ribbon path circularly, I need to define that gradient by tying radial distances from the center point to a color.  That means I need to FIRST (and this is what I wasn't doing) convert the radial distance to a corresponding elevation angle and THEN (also wasn't doing this) use that elevation angle to find the relative solar strength at that angle given h and k.
- I could FURTH improve the similarity of the two charts by reversing the algebra so that I could instead FIND the radial distance for regular interval in color/relative strength.  That way, since the color scale is the thing you are actually seeing a difference in, I can take more advantage of the 15 item resolution.  Currently, the middle points jump big stretches of color.
- Done.  It works well.

I also added the back button to the location selection screen ONLY when there is a current location selected, which could just be the default loaded as current.

## 2026-09-04
Kept working on the visual list from yesterday

## 2026-09-03
I am finally going to address some visual issues.  Ideas:
X labeling the year
X a drop down with some explanation of the chart itself
X change the overall horizontal alignment.  Reference the google or edge start page.  The app bar can be far left with actions far right, but the content should be centered.
X explanation of the UV bands
X change the value to percentage and call it strength
X make the location name label bigger
X in the map, don't zoom when you click.  Also, check what happens when you type something in and hit enter. It should definitely move there but probably not zoom, or at least not as much.

## 2026-09-02
Major bug: there is some latitude below which I get an error.  It says it is an index error where it index should be less than 256.

Another issue is that, for Phoenixville, the azimuth never seems to get "hot" enough.  I'll bet it is a problem with the scale.  I have a linear color scale, but strength is not linear.  It should get toward 0.9 strength much quicker and then flatten out.

## 2026-09-01
I am out of date with this log.  I have finally gotten the azimath angle visual basically working.  Currently, I am having numerous issues with some things not updating.  Clicking the button to update k does nothing.  Changing the color scheme changes some things, I think, but definitely not everything.

Current issues:
- hideToolTip keeps running.  After EVERY hover.  (solved by uncommenting IgnorePointer wrapped around tooltip)
- azimuth color scheme loaded to wrong scheme.  (solved by correcting colorValuesFromMap call to use colormap that was passed to it)
- Clicking a button to change k runs some functions, but the chart doesn't change.  Im not sure what exactly runs (solved.  The orbit data was being created in a CNP's create method, which referenced a value held in the stateful widget.  When the k value changed, it reran the build method, but Flutter did not recreate the provider.  So, this was changed so that k is served by a ValueNotifer and the orbit data is now a ChangeNotifierProxyProvider depending on that ValueNotifier.  Also, that widget is no longer stateful).
- When I clicked the button to change color scheme (i.e., the dropdown) stuff ran.  It looks like the saved settings updated, but nothing re painted.  Even when I got the azimuth chart to repaint by cliking another day, the color is still wrong.  (solved by fixing one call to the function that actually converts doubles to colors where it ignored the colormap passed to it.  The other places were solved by adding didUpdateWidget overrides for statefulwidgets.  This was because the colormap was passed to the widget, but the only place where it was referenced was in an update function rather than in the build() method itself.  So, when updating the widget, it would rerun the build method but not recreate update method.)

Next, I want to make the azimuth chart decent looking (compass point/lines and some marking of hours).  Also, add some way to move the tooltip to the top when the cursor is too low

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

## Testing
I really should learn about the various types of testing possible with Flutter.  Widget testing, etc.  This would be a good thing for me to learn in general, but it would also likely make my experience developing this app much faster.

# Notes
## Testing
### Mocking (mocktail)
You don't mock thing you are trying to test.  You mock things that need to be instantiated, accessed, etc. in order to create & use the thing you are trying to test.  If you make an object, and that object needs to access some API, for instance, you could Mock the object that handles the API call.  Then you use the when(() = {}) and similar to set up how the Mocked object should respond.  That way, you can feed your object a realistic response when it tried to call the API and instead calls the Mocked API.


# Future work
## Add a note about DST (pop up changes to always be correct local time, but y axis is solar time).

## Add some way of adjusting the number of y and x axis labels.  Either a setting or, even better, window size.

## Google Maps API Marker
There is some API that has been deprecated.   I think it is the thing that actually creates my marker.  It shows up in the console.

## See if there is a good way to add a "today" indicator.  If so, add a toggle for that.

## Add the ability to change the number of vertical lines

## debugDumpRenderTree()?

## Make sure, at some point, to go to Google Cloud Console, go to my Google Maps API key,
and restrict it to HTTP Referrers and add your local development URL
(http://localhost:*) and your production domain so others cannot steal it.

##  Why do I check for non null default location?
If there is one, that means it has been
loaded, and current location notifier should have been called.  The only reason that would be
true but current location notifier value is null would be if the user somehow wiped the current
location (not sure if that is possible) or if the current location notifier just hasn't loaded
yet.  Maybe that is indeed why.  On the other hand, what is the harm?  Just processing time.

## I can get rid of a dependence by just calculating this myself.
LocationSelectorRoute line 126        double distanceInMeters = Geolocator.distanceBetween(

## I could make this a little more efficient by remembering the dayIndex from hover.
That way, when I click, I could just pass the day index rather than having to calculate it again.
ChartWidget line 131.

## Get rid of that dumb google location code.  For clicks, just show the town and maybe some note about a speicific point.
Or consider forcing an address like Google Maps does for directions.

## I should check through my 1D vs. 2D conversions to improve indexing & width/height logic
Sometimes I pass nDays so that the giant 1D list can be chunked.  Other times, I hard code 96 and the other direction.  I should make all that soft coded and pass vertical length or something.

## IMPORTANT: add a note about direction of the surface.
In other words, the app calculates the strength of the sun on a surface perpindicular to the sunlight.  That is different from solar calculators, for instance, which usually either assume a fixed angle that you enter or assume parallel to the ground, roof, etc.  It also explains why many of the sun strengths will seem higher than people expect, especially in winter.  In the winter, it gets colder in temperate places because the sun's light falls on the ground at a steep angle and is therefore spread out of a larger area.  A spherical surface like your head, however, will not be impacted by this AT ALL!  The only reason the sun is less strong on your head in the winter is because it is traveling through more atmosphere...almost.  One other thing, although a much smaller point.  Imagine you were in London in winter time and stood still all day facing South.  While it is true that the strength of the sun at any moment would NOT be reduced because of the winter-time-spreading-out effect, it is also true that the sun would be moving accross your face over the day (from left ear to nose to right ear).  That means that any particular bit of your skin would get less total sunlight over the day.  Compare that to do exactly the same thing in summer.  Because the sun is higher, it is more hitting the top of your head, which means that as it arcs through the sky through the day, the same bits of your scalp are getting the sun light, leading to more total sunlight throughout the day.

That last point seems as first way too subtle, abstract, or inconsequential to worry about, and that is true for our silly example of standing still all day.  It is true, however, that as humans go about a day outside, they are very likely to move their face in many different directions but remain standing and looking horizontally almost all the time.  This does indeed mean that surfaces that are perpindicular to winter-time sun are more likely to receive less sunlight throughout a winter day compared to surface perpindicular to summer-time sun throughout a summer day, but NOT because of the "spreading out" effect that makes is colder in winter.less than 45degrees in the sky.

## Should I bring in the 3D stuff I did in that other app and make the azimuth chart essentially a 3D rotatable snow globe?

## Improve hover location
There are probably a lot of improvements that could be made.  For now, though, at least make it jump up above pointer if it gets to the bottom (so it doesn't get cut off).

## Major: responsive design
Three approaches to the chart screen: Wrap, LayoutBuilder (using contstaints and building two diffrent trees), Flex (with layoutbuilder but it can make a row or a column depending on a member input, so it's the same widget for either one).

## I could probably make some of my ChangeNotifier's that are currently nullable classes to non-nullable.  Especially if they are exposed via a ChangeNotifierProxyProvider.
I just learned that, not only does the update function "right" after the create fuction, literally nothing is built in between.  That means, it is completely safe to create the Notifier with some dummy/blank (but not null) value that will get immediately replaced by a real value.

## I just read about extension types.  They seem very handy for times when, for instance, an index has to be positive, but the type is simply int.  I could use an index extension type so that it costs nothing but makes it totally safe.
I could do this with an assert in the default constructor's initialization list or used a factory constructor that first checks the value and throws if there is a problem.

## I should just make the tooltip a custom render object
I am running into issues like making the layout of the text look good and not jittery.  I realize now that the time and date should each stay in the same relative location regrdless of how many digits they are.

## Come up with a more robust solution for timezone abbreviation.  Currently, if the system supplies something longer than 3 characters, it just gets omitted.