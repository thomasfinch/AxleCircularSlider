AxleCircularSlider
==================

The CircularSlider class was used in the Axle jailbreak tweak for the circular volume and brightness sliders.

Creating a slider:
CircularSlider *brightSlider = [[CircularSlider alloc] initWithFrame:CGRectMake(14,345,65,65) function:kFunctionBrightness];

Requires the QuartzCore and CoreGraphics frameworks. BackBoardServices is needed for changing the brightness.

This could easily be used to replace a normal UISlider, the code would just have to be modified to change where the images are loaded from.


