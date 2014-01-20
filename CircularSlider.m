//
//  CircularSlider.m
//  CircularSlider
//
//  Created by Thomas Finch on 4/9/13.
//  Copyright (c) 2013 Thomas Finch. All rights reserved.
//

//#import <SpringBoard/SpringBoard.h>

#import "CircularSlider.h"
#import "SBMediaController.h"
#import "SBHUDController.h"
#import "SBBrightnessHUDView.h"

#define MIN_ANGLE -(5*M_PI)/12
#define MAX_ANGLE (17*M_PI)/12

extern float BKSDisplayBrightnessGetCurrent();

static SBBrightnessHUDView *brightnessHUD;
static SBHUDController *sharedHUDController;
static CGSize knobDimensions;
static float knobScale;

//Volume & brightness manager class. Needed to change volume & brightness from a different thread
@interface VolumeBrightnessManager : NSObject
+(void)setBrightness:(NSNumber*)value;
+(void)setVolume:(NSNumber*)value;
@end

@implementation VolumeBrightnessManager
extern void BKSDisplayBrightnessSet(float level, int _unknown /* use 1 */);
+(void)setBrightness:(NSNumber*)value{ BKSDisplayBrightnessSet([value floatValue], 1); }
+(void)setVolume:(NSNumber*)value{ [[objc_getClass("SBMediaController") sharedInstance] _changeVolumeBy:([value floatValue]-[[objc_getClass("SBMediaController") sharedInstance] volume])]; }
@end

@implementation CircularSlider

@synthesize value;
@synthesize isKnobBeingTouched;

-(id)initWithFrame:(CGRect)frame function:(int)func
{
    self = [super init];
    if (self)
    {
        //Set instance variables
        isKnobBeingTouched = NO;
        [self setBackgroundColor:[UIColor clearColor]];
        function = func;
        self.frame = frame;
        knobAngle = MIN_ANGLE;
        brightnessHUD  = [[objc_getClass("SBBrightnessHUDView") alloc] init];
        sharedHUDController = [objc_getClass("SBHUDController") sharedHUDController];
        bundle = [[NSBundle alloc] initWithPath:@"/Library/Application Support/Axle/Images.bundle"];
        
        //Calculate the location and size of the slider bar and knob based on the frame
        barCenter.x = CGRectGetMidX(frame) - frame.origin.x;
        barCenter.y = CGRectGetMidY(frame) - frame.origin.y;
        
        barRadius = [[UIImage imageNamed:@"SliderWheelTrackMin" inBundle:bundle] size].width/2;
        knobRadius = [[UIImage imageNamed:@"SliderThumb" inBundle:bundle] size].width/2;
        imageSize = [[UIImage imageNamed:@"IconBrightness" inBundle:bundle] size].width/2;
        CGSize barDimensions = [[UIImage imageNamed:@"SliderWheelTrackMin" inBundle:bundle] size];
        knobDimensions = [[UIImage imageNamed:@"SliderThumb" inBundle:bundle] size];
        CGSize centerImageDimensions = [[UIImage imageNamed:@"IconBrightness" inBundle:bundle] size];
        
        knobCenter.x = barCenter.x+(barRadius*.88*cosf(knobAngle));
        knobCenter.y = barCenter.y-(barRadius*.88*sinf(knobAngle));
        knobScale = 2*(knobRadius/knobDimensions.height);
        float barScale = 2*(barRadius/barDimensions.width);
        float centerImageScale = 2*(imageSize/centerImageDimensions.width);
        
        //Import the images into their corresponding CALayers and add the layers to the view
        barEmptyLayer = [CALayer layer];
        barFillLayer = [CALayer layer];
        knobLayer = [CALayer layer];
        centerImageLayer = [CALayer layer];
        barEmptyLayer.contents = (id)[[UIImage imageNamed:@"SliderWheelTrackMin" inBundle:bundle] CGImage];
        barFillLayer.contents = (id)[[UIImage imageNamed:@"SliderWheelTrackMax" inBundle:bundle] CGImage];
        knobLayer.contents = (id)[[UIImage imageNamed:@"SliderThumb" inBundle:bundle] CGImage];
        if (function == kFunctionVolume)
            centerImageLayer.contents = (id)[[UIImage imageNamed:@"IconVolume" inBundle:bundle] CGImage];
        else
            centerImageLayer.contents = (id)[[UIImage imageNamed:@"IconBrightness" inBundle:bundle] CGImage];
        [self.layer addSublayer:barEmptyLayer];
        [self.layer addSublayer:barFillLayer];
        [self.layer addSublayer:knobLayer];
        [self.layer addSublayer:centerImageLayer];
        
        //Additional setup on the layers
        clippingLayer = [CAShapeLayer layer];
        clippingLayer.anchorPoint = CGPointMake(0.0,0.0);
        clippingLayer.bounds = CGRectMake(barCenter.x-barRadius, barCenter.y-barRadius, barDimensions.width*barScale, barDimensions.height*barScale);
        barEmptyLayer.frame = CGRectMake(barCenter.x-barRadius, barCenter.y-barRadius, barDimensions.width*barScale, barDimensions.height*barScale);
        barFillLayer.mask = clippingLayer;
        barFillLayer.frame = CGRectMake(barCenter.x-barRadius, barCenter.y-barRadius, barDimensions.width*barScale, barDimensions.height*barScale);
        centerImageLayer.frame = CGRectMake(barCenter.x-imageSize, barCenter.y-imageSize, centerImageDimensions.width*centerImageScale, centerImageDimensions.width*centerImageScale);
        
        [self updateValue];
        [self updateLayers];
    }
    return self;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (touches.count > 1)
        return;
    CGPoint touchLocation = [[touches anyObject] locationInView:self];
    isKnobBeingTouched = (hypotf(touchLocation.x-knobCenter.x, touchLocation.y-knobCenter.y) <= knobRadius*2); //if the touch is on the slider knob
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([touches count] > 1)
    {
        isKnobBeingTouched = NO;
        return;
    }
    
    if (isKnobBeingTouched)
    {
        CGPoint touchLocation = [[touches anyObject] locationInView:self];
        float percent = 1.0-((knobAngle-MIN_ANGLE)/(MAX_ANGLE-MIN_ANGLE));
        if (percent >= .99 || percent <= .01) //if slider is near the ends of the bar
        {
            //use vector method
            
            float touchVector[2] = {touchLocation.x-knobCenter.x, touchLocation.y-knobCenter.y}; //gets the vector of the difference between the touch location and the knob center
            float tangentVector[2] = {knobCenter.y-barCenter.y, barCenter.x-knobCenter.x}; //gets a vector tangent to the circle at the center of the knob
            float scalarProj = (touchVector[0]*tangentVector[0] + touchVector[1]*tangentVector[1])/sqrt((tangentVector[0]*tangentVector[0])+(tangentVector[1]*tangentVector[1])); //calculates the scalar projection of the touch vector onto the tangent vector
            knobAngle += scalarProj/barRadius;
            
            if (knobAngle > MAX_ANGLE) //ensure knob is always on the bar
                knobAngle = MAX_ANGLE;
            if (knobAngle < MIN_ANGLE)
                knobAngle = MIN_ANGLE;
            
            knobAngle = fmodf(knobAngle, 2*M_PI); //Ensures knobAngle is always between 0 and 2*Pi
        }
        else
        {
            //use polar coordinate method
            
            if (barCenter.x-touchLocation.x < 0) //right side
                knobAngle = fmodf(-atanf((barCenter.y - touchLocation.y)/(barCenter.x - touchLocation.x)),2*M_PI); //for -pi/2 to pi/2
            else //left side
                knobAngle = fmodf(-atanf((barCenter.y - touchLocation.y)/(barCenter.x - touchLocation.x))+M_PI,2*M_PI); //for pi/2 to 3*pi/2
        }
        
        knobCenter.x = barCenter.x+(barRadius*.87*cosf(knobAngle));
        knobCenter.y = barCenter.y-(barRadius*.87*sinf(knobAngle));
        
        [self updateLayers];

        
        //sets the brightness or volume based on the new value
        if (function == kFunctionBrightness)
        {
            [NSThread detachNewThreadSelector:@selector(setBrightness:) toTarget:objc_getClass("VolumeBrightnessManager") withObject:[NSNumber numberWithFloat:[self value]]];
            
            //displays the brightness HUD manually
            brightnessHUD.progress = [self value];
            [sharedHUDController presentHUDView:brightnessHUD autoDismissWithDelay:1.5];
        }
        else
            [NSThread detachNewThreadSelector:@selector(setVolume:) toTarget:objc_getClass("VolumeBrightnessManager") withObject:[NSNumber numberWithFloat:[self value]]];
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    isKnobBeingTouched = NO;
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    isKnobBeingTouched = NO;
}

-(void)updateValue
{
    //gets the new value either from current brightness or volume
    float newValue;
    if (function == kFunctionBrightness)
        newValue = BKSDisplayBrightnessGetCurrent();
    else
        [[objc_getClass("AVSystemController") sharedAVSystemController] getVolume:&newValue forCategory:@"Audio/Video"];
    
    //updates the knob angle and knob center coordinates from the new value
    float percentDone = 1.0-newValue;
    knobAngle = MIN_ANGLE+(percentDone*(MAX_ANGLE-MIN_ANGLE));
    knobAngle = fmodf(knobAngle, 2*M_PI);
    knobCenter.x = barCenter.x+(barRadius*.88*cosf(knobAngle));
    knobCenter.y = barCenter.y-(barRadius*.88*sinf(knobAngle));
    
    [self updateLayers];
}

-(void)setImageVisible:(bool)visible
{
    centerImageLayer.hidden = !visible;
}

-(void)updateLayers
{
    [CATransaction begin];
    [CATransaction setAnimationDuration:0];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, barCenter.x, barCenter.y);
    CGPathAddLineToPoint(path, NULL, barCenter.x, barCenter.y+barRadius);
    CGPathAddArc(path, NULL, barCenter.x, barCenter.y, barRadius*1.05,(M_PI)/2, -knobAngle, 0);
    CGPathAddLineToPoint(path, NULL, barCenter.x, barCenter.y);
    clippingLayer.path = path;
    
    knobLayer.frame = CGRectMake(knobCenter.x-knobRadius, knobCenter.y-knobRadius, knobDimensions.width*knobScale, knobDimensions.height*knobScale);
    
    [CATransaction commit];
    
    value = 1.0-((knobAngle-MIN_ANGLE)/(MAX_ANGLE-MIN_ANGLE));
}

-(void)dealloc
{
    [centerImageLayer release];
    [knobLayer release];
    [barEmptyLayer release];
    [barFillLayer release];
    [clippingLayer release];
    [brightnessHUD release];
    [sharedHUDController release];
    [super dealloc];
}

@end
