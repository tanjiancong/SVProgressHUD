//
//  SVProgressHUD.h
//  SVProgressHUD, https://github.com/TransitApp/SVProgressHUD
//
//  Copyright 2011-2014 Sam Vermette. All rights reserved.
//

#if !__has_feature(objc_arc)
#error SVProgressHUD is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#import "SVProgressHUD.h"
#import "SVIndefiniteAnimatedView.h"
#import "SVRadialGradientLayer.h"

#import <QuartzCore/QuartzCore.h>

NSString * const SVProgressHUDDidReceiveTouchEventNotification = @"SVProgressHUDDidReceiveTouchEventNotification";
NSString * const SVProgressHUDDidTouchDownInsideNotification = @"SVProgressHUDDidTouchDownInsideNotification";
NSString * const SVProgressHUDWillDisappearNotification = @"SVProgressHUDWillDisappearNotification";
NSString * const SVProgressHUDDidDisappearNotification = @"SVProgressHUDDidDisappearNotification";
NSString * const SVProgressHUDWillAppearNotification = @"SVProgressHUDWillAppearNotification";
NSString * const SVProgressHUDDidAppearNotification = @"SVProgressHUDDidAppearNotification";

NSString * const SVProgressHUDStatusUserInfoKey = @"SVProgressHUDStatusUserInfoKey";

static SVProgressHUDStyle SVProgressHUDDefaultStyle;
static SVProgressHUDMaskType SVProgressHUDDefaultMaskType;
static CGFloat SVProgressHUDRingThickness;
static UIFont *SVProgressHUDFont;
static UIImage *SVProgressHUDSuccessImage;
static UIImage *SVProgressHUDErrorImage;

static const CGFloat SVProgressHUDRingRadius = 18;
static const CGFloat SVProgressHUDRingNoTextRadius = 24;
static const CGFloat SVProgressHUDParallaxDepthPoints = 10;
static const CGFloat SVProgressHUDUndefinedProgress = -1;

@interface SVProgressHUD ()

@property (nonatomic, readwrite) SVProgressHUDMaskType maskType;
@property (nonatomic, readwrite) SVProgressHUDStyle style;
@property (nonatomic, strong, readonly) NSTimer *fadeOutTimer;
@property (nonatomic, readonly, getter = isClear) BOOL clear;
@property (nonatomic, readonly, getter = usesLightTheme) BOOL lightTheme;

@property (nonatomic, strong) UIControl *overlayView;
@property (nonatomic, strong) UIView *hudView;

@property (nonatomic, strong) UILabel *stringLabel;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) SVIndefiniteAnimatedView *indefiniteAnimatedView;
@property (nonatomic, strong) SVRadialGradientLayer *backgroundGradientLayer;

@property (nonatomic, readwrite) CGFloat progress;
@property (nonatomic, readwrite) NSUInteger activityCount;
@property (nonatomic, strong) CAShapeLayer *backgroundRingLayer;
@property (nonatomic, strong) CAShapeLayer *ringLayer;

@property (nonatomic, readonly) CGFloat visibleKeyboardHeight;
@property (nonatomic, assign) UIOffset offsetFromCenter;

- (void)setStatus:(NSString*)string;
- (void)showProgress:(float)progress status:(NSString*)string;
- (void)showImage:(UIImage*)image status:(NSString*)status duration:(NSTimeInterval)duration;

- (void)dismiss;

- (void)registerNotifications;
- (NSDictionary *)notificationUserInfo;
- (void)moveToPoint:(CGPoint)newCenter rotateAngle:(CGFloat)angle;
- (void)positionHUD:(NSNotification*)notification;
- (NSTimeInterval)displayDurationForString:(NSString*)string;
- (UIColor *)foregroundColorForStyle;
- (UIColor *)backgroundColorForStyle;

@end


@implementation SVProgressHUD

+ (SVProgressHUD*)sharedView {
    static dispatch_once_t once;
    static SVProgressHUD *sharedView;
    dispatch_once(&once, ^ { sharedView = [[self alloc] initWithFrame:[[UIScreen mainScreen] bounds]]; });
    return sharedView;
}


#pragma mark - Setters

+ (void)setStatus:(NSString *)string {
    [[self sharedView] setStatus:string];
}

+ (void)setDefaultStyle:(SVProgressHUDStyle)style{
    [self sharedView];
    SVProgressHUDDefaultStyle = style;
}

+ (void)setDefaultMaskType:(SVProgressHUDMaskType)maskType{
    [self sharedView];
    SVProgressHUDDefaultMaskType = maskType;
}

+ (void)setFont:(UIFont *)font {
    [self sharedView];
    SVProgressHUDFont = font;
}

+ (void)setRingThickness:(CGFloat)width {
    [self sharedView];
    SVProgressHUDRingThickness = width;
}

+ (void)setSuccessImage:(UIImage *)image {
    [self sharedView];
    SVProgressHUDSuccessImage = image;
}

+ (void)setErrorImage:(UIImage *)image {
    [self sharedView];
    SVProgressHUDErrorImage = image;
}


#pragma mark - Show Methods

+ (void)show {
    [self showWithStatus:nil];
}

+ (void)showWithStatus:(NSString *)status {
    [self sharedView];
    [self showProgress:SVProgressHUDUndefinedProgress status:status];
}

+ (void)showWithStatus:(NSString*)status maskType:(SVProgressHUDMaskType)maskType {
    [self sharedView];
    [self showProgress:SVProgressHUDUndefinedProgress status:status];
}

+ (void)showProgress:(float)progress {
    [self showProgress:progress status:nil];
}

+ (void)showProgress:(float)progress status:(NSString *)status {
    [[self sharedView] showProgress:progress status:status];
}


#pragma mark - Show then dismiss methods

+ (void)showSuccessWithStatus:(NSString *)string {
    [self sharedView];
    [self showImage:SVProgressHUDSuccessImage status:string];
}

+ (void)showErrorWithStatus:(NSString *)string {
    [self sharedView];
    [self showImage:SVProgressHUDErrorImage status:string];
}

+ (void)showImage:(UIImage *)image status:(NSString *)string {
    NSTimeInterval displayInterval = [[self sharedView] displayDurationForString:string];
    [[self sharedView] showImage:image status:string duration:displayInterval];
}


#pragma mark - Dismiss Methods

+ (void)popActivity {
    if([self sharedView].activityCount > 0)
        [self sharedView].activityCount--;
    if([self sharedView].activityCount == 0)
        [[self sharedView] dismiss];
}

+ (void)dismiss {
    if ([self isVisible]) {
        [[self sharedView] dismiss];
    }
}


#pragma mark - Offset

+ (void)setOffsetFromCenter:(UIOffset)offset {
    [self sharedView].offsetFromCenter = offset;
}

+ (void)resetOffsetFromCenter {
    [self setOffsetFromCenter:UIOffsetZero];
}


#pragma mark - Instance Methods

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.alpha = 0.0f;
        self.activityCount = 0;
        
        SVProgressHUDDefaultMaskType = SVProgressHUDMaskTypeNone;
        SVProgressHUDDefaultStyle = SVProgressHUDStyleLight;
        if ([UIFont respondsToSelector:@selector(preferredFontForTextStyle:)]) {
            SVProgressHUDFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        } else {
            SVProgressHUDFont = [UIFont systemFontOfSize:14.0f];
        }
        if ([[UIImage class] instancesRespondToSelector:@selector(imageWithRenderingMode:)]) {
            SVProgressHUDSuccessImage = [[UIImage imageNamed:@"SVProgressHUD.bundle/success"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            SVProgressHUDErrorImage = [[UIImage imageNamed:@"SVProgressHUD.bundle/error"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            SVProgressHUDSuccessImage = [UIImage imageNamed:@"SVProgressHUD.bundle/success"];
            SVProgressHUDErrorImage = [UIImage imageNamed:@"SVProgressHUD.bundle/error"];
        }
        SVProgressHUDRingThickness = 2;
    }
    
    return self;
}

- (void)updateHUDFrame {
    CGFloat hudWidth = 100.0f;
    CGFloat hudHeight = 100.0f;
    CGFloat stringHeightBuffer = 20.0f;
    CGFloat stringAndContentHeightBuffer = 80.0f;
    
    CGFloat stringWidth = 0.0f;
    CGFloat stringHeight = 0.0f;
    CGRect labelRect = CGRectZero;
    
    // Check if an image or progress ring is displayed
    BOOL imageUsed = (self.imageView.image) || (self.imageView.hidden);
    BOOL progressUsed = (self.progress != SVProgressHUDUndefinedProgress) && (self.progress >= 0.0f);
    
    // Calculate and apply sizes
    NSString *string = self.stringLabel.text;
    if(string) {
        CGSize constraintSize = CGSizeMake(200.0f, 300.0f);
        CGRect stringRect;
        if ([string respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
            stringRect = [string boundingRectWithSize:constraintSize
                                              options:(NSStringDrawingUsesFontLeading|NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin)
                                           attributes:@{NSFontAttributeName: self.stringLabel.font}
                                              context:NULL];
        } else {
            CGSize stringSize;
            
            if ([string respondsToSelector:@selector(sizeWithAttributes:)])
                stringSize = [string sizeWithAttributes:@{NSFontAttributeName:[UIFont fontWithName:self.stringLabel.font.fontName size:self.stringLabel.font.pointSize]}];
            else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
                stringSize = [string sizeWithFont:self.stringLabel.font constrainedToSize:CGSizeMake(200.0f, 300.0f)];
#pragma clang diagnostic pop
            
            stringRect = CGRectMake(0.0f, 0.0f, stringSize.width, stringSize.height);
        }
        stringWidth = stringRect.size.width;
        stringHeight = ceil(CGRectGetHeight(stringRect));
        
        if (imageUsed || progressUsed)
            hudHeight = stringAndContentHeightBuffer + stringHeight;
        else
            hudHeight = stringHeightBuffer + stringHeight;
        
        if(stringWidth > hudWidth)
            hudWidth = ceil(stringWidth/2)*2;
        
        CGFloat labelRectY = (imageUsed || progressUsed) ? 68.0f : 9.0f;
        
        if(hudHeight > 100.0f) {
            labelRect = CGRectMake(12.0f, labelRectY, hudWidth, stringHeight);
            hudWidth += 24.0f;
        } else {
            hudWidth += 24.0f;
            labelRect = CGRectMake(0.0f, labelRectY, hudWidth, stringHeight);
        }
    }
    
    // Update values on suviews
    self.hudView.bounds = CGRectMake(0.0f, 0.0f, hudWidth, hudHeight);
    [self updateBlurBounds];
    
    if(string)
        self.imageView.center = CGPointMake(CGRectGetWidth(self.hudView.bounds)/2, 36.0f);
    else
       	self.imageView.center = CGPointMake(CGRectGetWidth(self.hudView.bounds)/2, CGRectGetHeight(self.hudView.bounds)/2);
    
    self.stringLabel.hidden = NO;
    self.stringLabel.frame = labelRect;
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    if(string) {
        self.indefiniteAnimatedView.radius = SVProgressHUDRingRadius;
        [self.indefiniteAnimatedView sizeToFit];
        
        CGPoint center = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), 36.0f);
        self.indefiniteAnimatedView.center = center;
        
        if(self.progress != SVProgressHUDUndefinedProgress)
            self.backgroundRingLayer.position = self.ringLayer.position = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), 36.0f);
    } else {
        self.indefiniteAnimatedView.radius = SVProgressHUDRingNoTextRadius;
        [self.indefiniteAnimatedView sizeToFit];
        
        CGPoint center = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), CGRectGetHeight(self.hudView.bounds)/2);
        self.indefiniteAnimatedView.center = center;
        
        if(self.progress != SVProgressHUDUndefinedProgress)
            self.backgroundRingLayer.position = self.ringLayer.position = CGPointMake((CGRectGetWidth(self.hudView.bounds)/2), CGRectGetHeight(self.hudView.bounds)/2);
    }
    
    [CATransaction commit];
}

- (void)updateMask{
    switch (self.maskType) {
        case SVProgressHUDMaskTypeBlack: {
            self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
            break;
        }
            
        case SVProgressHUDMaskTypeGradient: {
            self.backgroundGradientLayer = [SVRadialGradientLayer layer];
            self.backgroundGradientLayer.frame = self.bounds;
            CGPoint gradientCenter = self.center;
            gradientCenter.y = (self.bounds.size.height - self.visibleKeyboardHeight) / 2;
            self.backgroundGradientLayer.gradientCenter = gradientCenter;
            [self.backgroundGradientLayer setNeedsDisplay];
            
            [self.layer addSublayer:self.backgroundGradientLayer];
            break;
        }
        default:
            break;
    }
}

- (void)updateBlurBounds{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if(NSClassFromString(@"UIBlurEffect")){
        // Remove background color, else the effect would not work
        self.hudView.backgroundColor = [UIColor clearColor];
        
        // Remove any old instances of UIVisualEffectViews
        for (UIView *subview in self.hudView.subviews){
            if([subview isKindOfClass:[UIVisualEffectView class]]){
                [subview removeFromSuperview];
            }
        }
        
        // Create blur effect
        UIBlurEffectStyle blurEffectStyle = self.usesLightTheme ? UIBlurEffectStyleLight : UIBlurEffectStyleDark;
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurEffectStyle];
        UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurEffectView.autoresizingMask = self.hudView.autoresizingMask;
        blurEffectView.bounds = self.bounds;
        
        // Add vibrancy to the blur effect to make it more vivid
        UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
        UIVisualEffectView *vibrancyEffectView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
        vibrancyEffectView.autoresizingMask = self.hudView.autoresizingMask;
        vibrancyEffectView.bounds = self.bounds;
        [blurEffectView.contentView addSubview:vibrancyEffectView];
        
        [self.hudView insertSubview:blurEffectView atIndex:0];
    }
#endif
}

- (void)updateMotionEffectForOrientation:(UIInterfaceOrientation)orientation{
    if ([_hudView respondsToSelector:@selector(addMotionEffect:)]) {
        UIInterpolatingMotionEffectType motionEffectType = UIInterfaceOrientationIsPortrait(orientation) ? UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis : UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis;
        UIInterpolatingMotionEffect *effectX = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:motionEffectType];
        effectX.minimumRelativeValue = @(-SVProgressHUDParallaxDepthPoints);
        effectX.maximumRelativeValue = @(SVProgressHUDParallaxDepthPoints);
        
        motionEffectType = UIInterfaceOrientationIsPortrait(orientation) ? UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis : UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis;
        UIInterpolatingMotionEffect *effectY = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:motionEffectType];
        effectY.minimumRelativeValue = @(-SVProgressHUDParallaxDepthPoints);
        effectY.maximumRelativeValue = @(SVProgressHUDParallaxDepthPoints);
        
        UIMotionEffectGroup *effectGroup = [[UIMotionEffectGroup alloc] init];
        effectGroup.motionEffects = @[effectX, effectY];
        
        // Update motion effets
        self.hudView.motionEffects = @[];
        [self.hudView addMotionEffect:effectGroup];
    }
}


- (void)setStatus:(NSString *)string {
    self.stringLabel.text = string;
    [self updateHUDFrame];
    
}

- (void)setFadeOutTimer:(NSTimer *)newTimer {
    if(_fadeOutTimer)
        [_fadeOutTimer invalidate], _fadeOutTimer = nil;
    
    if(newTimer)
        _fadeOutTimer = newTimer;
}


#pragma mark - Notifications and their handling

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionHUD:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
}


- (NSDictionary *)notificationUserInfo{
    return (self.stringLabel.text ? @{SVProgressHUDStatusUserInfoKey : self.stringLabel.text} : nil);
}


- (void)positionHUD:(NSNotification*)notification {
    CGFloat keyboardHeight = 0.0f;
    double animationDuration = 0.0;
    
    self.frame = UIScreen.mainScreen.bounds;
    
    UIInterfaceOrientation orientation = UIApplication.sharedApplication.statusBarOrientation;
    // no transforms applied to window in iOS 8, but only if compiled with iOS 8 sdk as base sdk, otherwise system supports old rotation logic.
    BOOL ignoreOrientation = NO;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]) {
        ignoreOrientation = YES;
    }
#endif
    
    // Get keyboardHeight in regards to current state
    if(notification) {
        NSDictionary* keyboardInfo = [notification userInfo];
        CGRect keyboardFrame = [[keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
        animationDuration = [[keyboardInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        
        if(notification.name == UIKeyboardWillShowNotification || notification.name == UIKeyboardDidShowNotification) {
            if(ignoreOrientation || UIInterfaceOrientationIsPortrait(orientation))
                keyboardHeight = CGRectGetHeight(keyboardFrame);
            else
                keyboardHeight = CGRectGetWidth(keyboardFrame);
        }
    } else {
        keyboardHeight = self.visibleKeyboardHeight;
    }
    
    // Get the currently active frame of the display (depends on orientation)
    CGRect orientationFrame = self.bounds;
    CGRect statusBarFrame = UIApplication.sharedApplication.statusBarFrame;
    
    if(!ignoreOrientation && UIInterfaceOrientationIsLandscape(orientation)) {
        float temp = CGRectGetWidth(orientationFrame);
        orientationFrame.size.width = CGRectGetHeight(orientationFrame);
        orientationFrame.size.height = temp;
        
        temp = CGRectGetWidth(statusBarFrame);
        statusBarFrame.size.width = CGRectGetHeight(statusBarFrame);
        statusBarFrame.size.height = temp;
    }
    
    // Update the motion effects in regards to orientation
    [self updateMotionEffectForOrientation:orientation];
    
    // Calculate available height for display
    CGFloat activeHeight = CGRectGetHeight(orientationFrame);
    if(keyboardHeight > 0)
        activeHeight += CGRectGetHeight(statusBarFrame)*2;
    activeHeight -= keyboardHeight;
    
    CGFloat posX = CGRectGetWidth(orientationFrame)/2;
    CGFloat posY = floor(activeHeight*0.45);

    CGPoint newCenter;
    CGFloat rotateAngle;
    
    // Update posX and posY in regards to orientation
    if (ignoreOrientation) {
        rotateAngle = 0.0;
        newCenter = CGPointMake(posX, posY);
    } else {
        switch (orientation) {
            case UIInterfaceOrientationPortraitUpsideDown:
                rotateAngle = M_PI;
                newCenter = CGPointMake(posX, CGRectGetHeight(orientationFrame)-posY);
                break;
            case UIInterfaceOrientationLandscapeLeft:
                rotateAngle = -M_PI/2.0f;
                newCenter = CGPointMake(posY, posX);
                break;
            case UIInterfaceOrientationLandscapeRight:
                rotateAngle = M_PI/2.0f;
                newCenter = CGPointMake(CGRectGetHeight(orientationFrame)-posY, posX);
                break;
            default: // Same as UIInterfaceOrientationPortrait
                rotateAngle = 0.0;
                newCenter = CGPointMake(posX, posY);
                break;
        }
    }
    
    if(notification) {
        // Animate update if notification was present
        [UIView animateWithDuration:animationDuration
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             [self moveToPoint:newCenter rotateAngle:rotateAngle];
                             [self setNeedsDisplay];
                         } completion:NULL];
    } else {
        [self moveToPoint:newCenter rotateAngle:rotateAngle];
        [self setNeedsDisplay];
    }
    
}

- (void)moveToPoint:(CGPoint)newCenter rotateAngle:(CGFloat)angle {
    self.hudView.transform = CGAffineTransformMakeRotation(angle);
    self.hudView.center = CGPointMake(newCenter.x + self.offsetFromCenter.horizontal, newCenter.y + self.offsetFromCenter.vertical);
}


#pragma mark - Event handling

- (void)overlayViewDidReceiveTouchEvent:(id)sender forEvent:(UIEvent *)event {
    [[NSNotificationCenter defaultCenter] postNotificationName:SVProgressHUDDidReceiveTouchEventNotification object:event];
    
    UITouch *touch = event.allTouches.anyObject;
    CGPoint touchLocation = [touch locationInView:self];
    
    if (CGRectContainsPoint(self.hudView.frame, touchLocation)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SVProgressHUDDidTouchDownInsideNotification object:event];
    }
}


#pragma mark - Master show/dismiss methods

- (void)showProgress:(float)progress status:(NSString*)string {
    if(!self.overlayView.superview){
        NSEnumerator *frontToBackWindows = [UIApplication.sharedApplication.windows reverseObjectEnumerator];
        UIScreen *mainScreen = UIScreen.mainScreen;
        
        for (UIWindow *window in frontToBackWindows){
            if (window.screen == mainScreen && window.windowLevel == UIWindowLevelNormal) {
                [window addSubview:self.overlayView];
                break;
            }
        }
    } else {
        // Ensure that overlay will be exactly on top of rootViewController (which may be changed during runtime).
        [self.overlayView.superview bringSubviewToFront:self.overlayView];
    }
    
    if(!self.superview){
        [self.overlayView addSubview:self];
    }
    
    self.fadeOutTimer = nil;
    self.imageView.hidden = YES;
    self.maskType = SVProgressHUDDefaultMaskType;
    self.style = SVProgressHUDDefaultStyle;
    self.progress = progress;
    
    self.stringLabel.text = string;
    [self updateHUDFrame];
    [self updateMask];
    
    if(progress >= 0) {
        self.imageView.image = nil;
        self.imageView.hidden = NO;
        [self.indefiniteAnimatedView removeFromSuperview];
        
        self.ringLayer.strokeEnd = progress;
        
        if(progress == 0){
            self.activityCount++;
        }
    } else {
        self.activityCount++;
        [self cancelRingLayerAnimation];
        [self.hudView addSubview:self.indefiniteAnimatedView];
    }
    
    if(self.maskType != SVProgressHUDMaskTypeNone) {
        self.overlayView.userInteractionEnabled = YES;
        self.accessibilityLabel = string;
        self.isAccessibilityElement = YES;
    } else {
        self.overlayView.userInteractionEnabled = NO;
        self.hudView.accessibilityLabel = string;
        self.hudView.isAccessibilityElement = YES;
    }
    
    [self.overlayView setHidden:NO];
    self.overlayView.backgroundColor = [UIColor clearColor];
    [self positionHUD:nil];
    
    // Appear
    if(self.alpha != 1 || self.hudView.alpha != 1) {
        NSDictionary *userInfo = [self notificationUserInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:SVProgressHUDWillAppearNotification
                                                            object:nil
                                                          userInfo:userInfo];
        
        [self registerNotifications];
        self.hudView.transform = CGAffineTransformScale(self.hudView.transform, 1.3, 1.3);
        
        if(self.isClear) {
            self.alpha = 1;
            self.hudView.alpha = 0;
        }
        
        [UIView animateWithDuration:0.15
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.hudView.transform = CGAffineTransformScale(self.hudView.transform, 1/1.3, 1/1.3);
                             
                             if(self.isClear){ // handle iOS 7 and 8 UIToolbar which not answers well to hierarchy opacity change
                                 self.hudView.alpha = 1;
                             } else {
                                 self.alpha = 1;
                             }
                         }
                         completion:^(BOOL finished){
                             [[NSNotificationCenter defaultCenter] postNotificationName:SVProgressHUDDidAppearNotification
                                                                                 object:nil
                                                                               userInfo:userInfo];
                             UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
                             UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, string);
                         }];
        
        [self setNeedsDisplay];
    }
}

- (UIImage *)image:(UIImage *)image withTintColor:(UIColor *)color{
    CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [image drawInRect:rect];
    CGContextSetFillColorWithColor(c, [color CGColor]);
    CGContextSetBlendMode(c, kCGBlendModeSourceAtop);
    CGContextFillRect(c, rect);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return tintedImage;
}

- (void)showImage:(UIImage *)image status:(NSString *)string duration:(NSTimeInterval)duration{
    self.progress = SVProgressHUDUndefinedProgress;
    [self cancelRingLayerAnimation];
    
    if(![self.class isVisible])
        [self.class show];
    
    UIColor *tintColor = self.foregroundColorForStyle;
    if ([self.imageView respondsToSelector:@selector(setTintColor:)])
        self.imageView.tintColor = tintColor;
    else
        image = [self image:image withTintColor:tintColor];
    
    self.imageView.image = image;
    self.imageView.hidden = NO;
    self.maskType = SVProgressHUDDefaultMaskType;
    self.style = SVProgressHUDDefaultStyle;
    
    self.stringLabel.text = string;
    [self updateHUDFrame];
    [self.indefiniteAnimatedView removeFromSuperview];
    
    if(self.maskType != SVProgressHUDMaskTypeNone) {
        self.accessibilityLabel = string;
        self.isAccessibilityElement = YES;
    } else {
        self.hudView.accessibilityLabel = string;
        self.hudView.isAccessibilityElement = YES;
    }
    
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, string);
    
    self.fadeOutTimer = [NSTimer timerWithTimeInterval:duration target:self selector:@selector(dismiss) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.fadeOutTimer forMode:NSRunLoopCommonModes];
}

- (void)dismiss {
    NSDictionary *userInfo = [self notificationUserInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:SVProgressHUDWillDisappearNotification
                                                        object:nil
                                                      userInfo:userInfo];
    
    self.activityCount = 0;
    [UIView animateWithDuration:0.15
                          delay:0
                        options:UIViewAnimationCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.hudView.transform = CGAffineTransformScale(self.hudView.transform, 0.8f, 0.8f);
                         if(self.isClear) // handle iOS 7 UIToolbar not answer well to hierarchy opacity change
                             self.hudView.alpha = 0.0f;
                         else
                             self.alpha = 0.0f;
                     }
                     completion:^(BOOL finished){
                         if(self.alpha == 0.0f || self.hudView.alpha == 0.0f) {
                             self.alpha = 0.0f;
                             self.hudView.alpha = 0.0f;
                             
                             [[NSNotificationCenter defaultCenter] removeObserver:self];
                             [self cancelRingLayerAnimation];
                             [_hudView removeFromSuperview];
                             _hudView = nil;
                             
                             [_overlayView removeFromSuperview];
                             _overlayView = nil;
                             
                             [_indefiniteAnimatedView removeFromSuperview];
                             _indefiniteAnimatedView = nil;
                             
                             UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
                             
                             [[NSNotificationCenter defaultCenter] postNotificationName:SVProgressHUDDidDisappearNotification
                                                                                 object:nil
                                                                               userInfo:userInfo];
                             
                             // Tell the rootViewController to update the StatusBar appearance
                             UIViewController *rootController = [[UIApplication sharedApplication] keyWindow].rootViewController;
                             if ([rootController respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
                                 [rootController setNeedsStatusBarAppearanceUpdate];
                             }
                             // uncomment to make sure UIWindow is gone from app.windows
                             //NSLog(@"%@", [UIApplication sharedApplication].windows);
                             //NSLog(@"keyWindow = %@", [UIApplication sharedApplication].keyWindow);
                         }
                     }];
}


#pragma mark - Ring progress animation

- (SVIndefiniteAnimatedView *)indefiniteAnimatedView {
    if (_indefiniteAnimatedView == nil) {
        _indefiniteAnimatedView = [[SVIndefiniteAnimatedView alloc] initWithFrame:CGRectZero];
        _indefiniteAnimatedView.radius = self.stringLabel.text ? SVProgressHUDRingRadius : SVProgressHUDRingNoTextRadius;
        [_indefiniteAnimatedView sizeToFit];
    }
    
    _indefiniteAnimatedView.strokeThickness = SVProgressHUDRingThickness;
    _indefiniteAnimatedView.strokeColor = self.foregroundColorForStyle;
    
    return _indefiniteAnimatedView;
}

- (CAShapeLayer *)ringLayer {
    if(!_ringLayer) {
        CGPoint center = CGPointMake(CGRectGetWidth(_hudView.frame)/2, CGRectGetHeight(_hudView.frame)/2);
        _ringLayer = [self createRingLayerWithCenter:center radius:SVProgressHUDRingRadius];
        [self.hudView.layer addSublayer:_ringLayer];
    }
    _ringLayer.strokeColor = self.foregroundColorForStyle.CGColor;
    _ringLayer.lineWidth = SVProgressHUDRingThickness;
    
    return _ringLayer;
}

- (CAShapeLayer *)backgroundRingLayer {
    if(!_backgroundRingLayer) {
        CGPoint center = CGPointMake(CGRectGetWidth(_hudView.frame)/2, CGRectGetHeight(_hudView.frame)/2);
        _backgroundRingLayer = [self createRingLayerWithCenter:center radius:SVProgressHUDRingRadius];
        _backgroundRingLayer.strokeEnd = 1;
        [self.hudView.layer addSublayer:_backgroundRingLayer];
    }
    _ringLayer.strokeColor = [self.foregroundColorForStyle colorWithAlphaComponent:0.1f].CGColor;
    _ringLayer.lineWidth = SVProgressHUDRingThickness;
    
    return _backgroundRingLayer;
}

- (void)cancelRingLayerAnimation {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [_hudView.layer removeAllAnimations];
    
    _ringLayer.strokeEnd = 0.0f;
    if (_ringLayer.superlayer) {
        [_ringLayer removeFromSuperlayer];
    }
    _ringLayer = nil;
    
    if (_backgroundRingLayer.superlayer) {
        [_backgroundRingLayer removeFromSuperlayer];
    }
    _backgroundRingLayer = nil;
    
    [CATransaction commit];
}

- (CAShapeLayer *)createRingLayerWithCenter:(CGPoint)center radius:(CGFloat)radius {
    
    UIBezierPath* smoothedPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(radius, radius) radius:radius startAngle:-M_PI_2 endAngle:(M_PI + M_PI_2) clockwise:YES];
    
    CAShapeLayer *slice = [CAShapeLayer layer];
    slice.contentsScale = [[UIScreen mainScreen] scale];
    slice.frame = CGRectMake(center.x-radius, center.y-radius, radius*2, radius*2);
    slice.fillColor = [UIColor clearColor].CGColor;
    slice.lineCap = kCALineCapRound;
    slice.lineJoin = kCALineJoinBevel;
    slice.path = smoothedPath.CGPath;
    
    return slice;
}

#pragma mark - Utilities

+ (BOOL)isVisible {
    return ([self sharedView].alpha == 1);
}


#pragma mark - Getters

- (NSTimeInterval)displayDurationForString:(NSString*)string {
    return MIN((float)string.length*0.06 + 0.5, 5.0);
}

- (UIColor *)foregroundColorForStyle{
    return self.usesLightTheme ? [UIColor blackColor] : [UIColor whiteColor];
}

- (UIColor *)backgroundColorForStyle{
    return self.usesLightTheme ? [UIColor whiteColor] : [UIColor blackColor];
}

- (BOOL)isClear { // used for iOS 7 and above
    return (self.maskType == SVProgressHUDMaskTypeClear || self.maskType == SVProgressHUDMaskTypeNone);
}

- (BOOL)usesLightTheme{
    return self.style == SVProgressHUDStyleLight;
}

- (UIControl *)overlayView {
    if(!_overlayView) {
        _overlayView = [[UIControl alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _overlayView.backgroundColor = [UIColor clearColor];
        [_overlayView addTarget:self action:@selector(overlayViewDidReceiveTouchEvent:forEvent:) forControlEvents:UIControlEventTouchDown];
    }
    return _overlayView;
}

- (UIView *)hudView {
    if(!_hudView) {
        _hudView = [[UIView alloc] initWithFrame:CGRectZero];
        _hudView.layer.cornerRadius = 14;
        _hudView.layer.masksToBounds = YES;
        _hudView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
    }
    _hudView.backgroundColor = self.backgroundColorForStyle;
    
    if(!_hudView.superview)
        [self addSubview:_hudView];

    return _hudView;
}

- (UILabel *)stringLabel {
    if (!_stringLabel) {
        _stringLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _stringLabel.backgroundColor = [UIColor clearColor];
        _stringLabel.adjustsFontSizeToFitWidth = YES;
        _stringLabel.textAlignment = NSTextAlignmentCenter;
        _stringLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        _stringLabel.numberOfLines = 0;
    }
    _stringLabel.textColor = self.foregroundColorForStyle;
    _stringLabel.font = SVProgressHUDFont;
    
    if(!_stringLabel.superview)
        [self.hudView addSubview:_stringLabel];
    
    return _stringLabel;
}

- (UIImageView *)imageView {
    if (!_imageView)
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 28.0f, 28.0f)];
    
    if(!_imageView.superview)
        [self.hudView addSubview:_imageView];
    
    return _imageView;
}

- (CGFloat)visibleKeyboardHeight {
    UIWindow *keyboardWindow = nil;
    for (UIWindow *testWindow in [[UIApplication sharedApplication] windows]) {
        if(![[testWindow class] isEqual:[UIWindow class]]) {
            keyboardWindow = testWindow;
            break;
        }
    }
    
    for (__strong UIView *possibleKeyboard in [keyboardWindow subviews]) {
        if ([possibleKeyboard isKindOfClass:NSClassFromString(@"UIPeripheralHostView")] || [possibleKeyboard isKindOfClass:NSClassFromString(@"UIKeyboard")]) {
            return CGRectGetHeight(possibleKeyboard.bounds);
        } else if ([possibleKeyboard isKindOfClass:NSClassFromString(@"UIInputSetContainerView")]) {
            for (__strong UIView *possibleKeyboardSubview in [possibleKeyboard subviews]) {
                if ([possibleKeyboardSubview isKindOfClass:NSClassFromString(@"UIInputSetHostView")]) {
                    return CGRectGetHeight(possibleKeyboardSubview.bounds);
                }
            }
        }
    }
    
    return 0;
}

@end

