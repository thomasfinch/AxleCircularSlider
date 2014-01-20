//
//  CircularSlider.h
//  CircularSlider
//
//  Created by Thomas Finch on 4/9/13.
//  Copyright (c) 2013 Thomas Finch. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define kFunctionBrightness 0
#define kFunctionVolume 1

@interface CircularSlider : UIView
{
    CGPoint barCenter, knobCenter;
    int function;
    float barRadius, knobRadius, knobAngle, imageSize;
    CALayer *centerImageLayer, *knobLayer, *barEmptyLayer, *barFillLayer;
    CAShapeLayer *clippingLayer;
    NSBundle *bundle;
}

@property(assign) float value;
@property(assign) BOOL isKnobBeingTouched;

-(id)initWithFrame:(CGRect)frame function:(int)func;
-(void)updateValue;
-(void)updateLayers;
-(void)setImageVisible:(bool)visible;

@end
