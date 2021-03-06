//
//  IWComposeViewController.m
//  ItcastWeibo
//
//  Created by MJ Lee on 14-5-18.
//  Copyright (c) 2014年 itcast. All rights reserved.
//

#import "IWComposeViewController.h"
#import "IWPlaceholderTextView.h"
#import "IWComposeToolbar.h"
#import "AFNetworking.h"
#import "IWAccount.h"
#import "IWToken.h"
#import "IWAccountTool.h"
#import "SVProgressHUD.h"
#import "IWWeiboTool.h"
#import "LYNetworkTool.h"
//选择相册
#import "LHGroupViewController.h"
#import "LHCollectionViewController.h"
#import "LHConst.h"

typedef enum _InputType
{
    InputType_Text     = 0,
    InputType_Emoji    = 1,
} InputType;

@interface IWComposeViewController () <IWComposeToolbarDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate,AGEmojiKeyboardViewDelegate, AGEmojiKeyboardViewDataSource>
{
    AGEmojiKeyboardView *_emojiKeyboardView;
}
@property (nonatomic, weak) UITextView *textView;
@property (nonatomic, weak) IWComposeToolbar *toolbar;
@property (nonatomic,strong) NSMutableArray *imageArray;//存放处理完的图片
@property (nonatomic,strong) NSMutableArray *scrollSubViews;//存放图片子视图
@property (nonatomic,strong) NSMutableArray *scrollSubFrame;//子视图的frame
@property (nonatomic,strong) NSMutableArray *localLength;//每张图片的尺寸
@property (nonatomic, assign) NSInteger selectedNumber;
@property (nonatomic, assign) InputType growingInputType;
@end

@implementation IWComposeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageArray = [NSMutableArray new];
    self.scrollSubViews = [NSMutableArray new];
    self.scrollSubFrame = [NSMutableArray new];
    self.localLength = [NSMutableArray new];
    _selectedNumber = 9;
    [self setupNavBar];
    [self setupTextView];
    [self setupToolbar];
    [self setupImageView];
    
    _growingInputType = InputType_Text;
    //创建键盘
    AGEmojiKeyboardView *emojiKeyboardView = [[AGEmojiKeyboardView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 216) dataSource:self];
    emojiKeyboardView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    emojiKeyboardView.delegate = self;
    _emojiKeyboardView = emojiKeyboardView;

}

- (void)setupImageView
{

}

- (void)setupToolbar
{
    IWComposeToolbar *toolbar = [[IWComposeToolbar alloc] init];
    toolbar.delegate = self;
    CGFloat toolbarH = 44;
    CGFloat toolbarW = self.view.frame.size.width;
    CGFloat toolbarY = self.view.frame.size.height - toolbarH;
    toolbar.frame = CGRectMake(0, toolbarY, toolbarW, toolbarH);
    [self.view addSubview:toolbar];
    self.toolbar = toolbar;
}

- (void)setupTextView
{
    IWPlaceholderTextView *textView = [[IWPlaceholderTextView alloc] init];
    textView.font = [UIFont systemFontOfSize:15];
    textView.placeholder = @"分享新鲜事...";
    textView.alwaysBounceVertical = YES;
    textView.frame = self.view.bounds;
    [self.view addSubview:textView];
    self.textView = textView;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(textDidChange:) name:UITextViewTextDidChangeNotification object:textView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
//    [self.textView becomeFirstResponder];
}

- (void)textDidChange:(NSNotification *)note
{
    self.navigationItem.rightBarButtonItem.enabled = self.textView.text.length != 0;
}

- (void)keyboardWillChangeFrame:(NSNotification *)note
{
    // 0.取出键盘动画的时间
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // 1.取得键盘最后的frame
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    // 2.计算控制器的view需要平移的距离
    CGFloat transformY = keyboardFrame.origin.y - self.view.frame.size.height;
    
    // 3.执行动画
    [UIView animateWithDuration:duration animations:^{
        self.toolbar.transform = CGAffineTransformMakeTranslation(0, transformY);
    }];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupNavBar
{
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.title = @"发无聊图";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleDone target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发送" style:UIBarButtonItemStyleDone target:self action:@selector(send)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)send
{
    if (self.imageArray.count) {
        [self sendStatusWithImage];
    } else {
        [self sendStatusWithoutImage];
    }
    
    // 关闭
//    [self dismissViewControllerAnimated:YES completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)sendStatusWithoutImage
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    IWAccount *account = [IWAccountTool account];
    params[@"userId"] = account.id;
    params[@"content"] = self.textView.text;
    params[@"device"] = [IWWeiboTool iphoneType];
    [[LYNetworkTool sharedNetworkTool] loadDataJsonInfoPost:IWArticleURL parameters:params success:^(id  _Nullable responseObject) {
        [SVProgressHUD showWithStatus:@"发送成功"];
        //通知首页刷新
        [[NSNotificationCenter defaultCenter] postNotificationName:PROBE_DEVICES_CHANGED object:nil];

    } failure:^(NSError * _Nullable error) {
        [SVProgressHUD showErrorWithStatus:@"发送失败"];
    }];
}

- (void)sendStatusWithImage
{
    // 1.创建请求管理对象
    IWToken *token = [IWAccountTool token];
    AFHTTPSessionManager *mgr = [AFHTTPSessionManager manager];
    mgr.requestSerializer = [AFJSONRequestSerializer serializer];
    mgr.responseSerializer = [AFJSONResponseSerializer serializer];
    [mgr.requestSerializer setValue:token.token forHTTPHeaderField:@"token"];
    
    // 2.封装请求参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    IWAccount *account = [IWAccountTool account];
    params[@"userId"] = account.id;
    params[@"content"] = self.textView.text;
    params[@"device"] = [IWWeiboTool iphoneType];
    
    // 3.发送请求
    [mgr POST:IWArticleURL parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        for (int i = 0; i<self.imageArray.count; i++) {
            UIImage *image = self.imageArray[i];
            NSData *data = UIImageJPEGRepresentation(image, 0.1);
            [formData appendPartWithFileData:data name:@"images" fileName:@"" mimeType:@"image/jpeg"];
        }

    } progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [SVProgressHUD showWithStatus:@"发送成功"];
        //通知首页刷新
        [[NSNotificationCenter defaultCenter] postNotificationName:PROBE_DEVICES_CHANGED object:nil];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [SVProgressHUD showErrorWithStatus:@"发送失败"];
    }];
}

- (void)cancel
{
//    [self dismissViewControllerAnimated:YES completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - toolbar代理
- (void)composeToolbar:(IWComposeToolbar *)toolbar didClickedButton:(IWComposeToolbarButtonType)buttonType
{
    switch (buttonType) {
        case IWComposeToolbarButtonTypeCamera: // 照相机
            [self openCamera];
            break;
            
        case IWComposeToolbarButtonTypePicture: // 相册
            [self openAlbum];
            break;
        case IWComposeToolbarButtonTypeEmotion: // 表情键盘
            [self openEmotion];
            break;
        default:
            break;
    }
}

/**
 *  照相机
 */
- (void)openCamera
{
    UIImagePickerController *ipc = [[UIImagePickerController alloc] init];
    ipc.sourceType = UIImagePickerControllerSourceTypeCamera;
    ipc.delegate = self;
    [self presentViewController:ipc animated:YES completion:nil];
}

/**
 *  相册
 */
- (void)openAlbum
{
    [self acquireLocal];
}

/**
 *  表情
 */
- (void)openEmotion
{
    if (_growingInputType == InputType_Text) {
        [_textView resignFirstResponder];
        _textView.inputView = _emojiKeyboardView;
        [_textView becomeFirstResponder];
        self.growingInputType = InputType_Emoji;
    } else if (_growingInputType == InputType_Emoji) {
        [_textView resignFirstResponder];
        _textView.inputView = nil;
        [_textView becomeFirstResponder];
        self.growingInputType = InputType_Text;
    }
}

#pragma mark --
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(nonnull NSDictionary<NSString *,id> *)info {
    __block UIImage *originalImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    __weak IWComposeViewController *weakSelf = self;
    void(^imageBlock)() = ^(UIImage *image){
        __strong IWComposeViewController *strongSelf = weakSelf;
        if (!image) {
            image = [info objectForKey:UIImagePickerControllerOriginalImage];
        }
        NSString *length  = [NSString stringWithFormat:@"%f*%f",image.size.width,image.size.height];
        [strongSelf.localLength addObject:length];
        [strongSelf.imageArray addObject:image];
    };
    void(^dismissBlock)() = ^(){//声明
        __strong IWComposeViewController *strongSelf = weakSelf;
        [picker dismissViewControllerAnimated:YES completion:^{
            [strongSelf setSpread];
        }];
    };
    //写入本地
    [[LHPhotoList sharePhotoTool]saveImageToAblum:originalImage completion:^(BOOL success, PHAsset *asset) {
        if (success) {//存成功
            [[LHPhotoList sharePhotoTool]requestImageForAsset:asset size:CGSizeMake(1080, 1920) resizeMode:PHImageRequestOptionsResizeModeFast completion:^(UIImage *image, NSDictionary *info) {
                originalImage = [UIImage imageWithData:UIImageJPEGRepresentation(originalImage, 1) scale:originalImage.scale];
                imageBlock(originalImage);
                dismissBlock();
            }];
        }else{//存取失败
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                originalImage = [UIImage imageWithData:UIImageJPEGRepresentation(originalImage, 1) scale:originalImage.scale];
                imageBlock(originalImage);
                dispatch_sync(dispatch_get_main_queue(), ^{
                    dismissBlock();
                });
            });
        }
    }];
}

#pragma mark --
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark --
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -获取本地图片
-(void)acquireLocal{
    LHGroupViewController *group = [[LHGroupViewController alloc]init];
    group.maxChooseNumber = _selectedNumber;
    __weak IWComposeViewController *weakSelf = self;
    group.backImageArray = ^(NSMutableArray<PHAsset *> *array){
        __strong IWComposeViewController *strongSelf = weakSelf;
        if (array) {
            _selectedNumber -= array.count;
            for (int i = 0; i<array.count; i++) {
                PHAsset *asset = array[i];
                [[LHPhotoList sharePhotoTool]requestImageForAsset:asset size:CGSizeMake(1080, 1920) resizeMode:PHImageRequestOptionsResizeModeFast completion:^(UIImage *image, NSDictionary *info) {
                    NSString *length  = [NSString stringWithFormat:@"%f*%f",image.size.width,image.size.height];
                    [_localLength addObject:length];
                    [_imageArray addObject:image];
                    [strongSelf setSpread];
                }];
            }
        }
    };
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:group] animated:YES completion:nil];
}

#pragma mark -展示UI在界面
-(void)setSpread{
    for (NSInteger i = self.scrollSubViews.count; i<self.imageArray.count; i++) {
        NSLog(@"%lu",(unsigned long)self.imageArray.count);
        UIImageView *photoView = [[UIImageView alloc] init];
        photoView.image = self.imageArray[i];
        photoView.userInteractionEnabled = YES;
        photoView.tag = i;
//        [photoView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoTap:)]];
        [self.textView addSubview:photoView];
        
        // 设置子控件的frame
        int maxColumns = 3;
        int col = i % maxColumns;
        long row = i / maxColumns;
        CGFloat photoX = col * (IWPhotoW + IWPhotoMargin);
        CGFloat photoY = row * (IWPhotoH + IWPhotoMargin) + 100;
        photoView.frame = CGRectMake(photoX, photoY, IWPhotoW, IWPhotoH);
        photoView.contentMode = UIViewContentModeScaleAspectFill;
        photoView.clipsToBounds = YES;
        //手势
        UIButton *deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        deleteBtn.frame = CGRectMake(IWPhotoW - 16, 0, 16, 16);
        deleteBtn.tag = 200+i;
        [deleteBtn setImage:[UIImage imageNamed:@"02"] forState:UIControlStateNormal];//正常显示
        [deleteBtn addTarget:self action:@selector(deleteImage:) forControlEvents:UIControlEventTouchUpInside];//删除
        [photoView addSubview:deleteBtn];
        
        [self.scrollSubFrame addObject:[NSValue valueWithCGRect:photoView.frame]];
        [self.scrollSubViews addObject:photoView];

    }

    
}

#pragma mark -删除图片
-(void)deleteImage:(UIButton *)btn{
    UIView *view  = btn.superview;
    NSInteger idx = [_scrollSubViews indexOfObject:view];
    [_scrollSubViews removeObject:view];
    [_imageArray removeObjectAtIndex:idx];
    [_localLength removeObjectAtIndex:idx];
    [_scrollSubFrame removeLastObject];
    [UIView animateWithDuration:0.2 animations:^{
        view.alpha = 0;
    } completion:^(BOOL finished) {
        [view removeFromSuperview];
        [UIView animateWithDuration:0.2 animations:^{
            for (NSInteger i = idx; i < self.scrollSubViews.count; i++) {
                UIView *item = self.scrollSubViews[i];
                item.frame = [(NSValue*)(self.scrollSubFrame[i]) CGRectValue];
            }
        } completion:^(BOOL finished) {
            if (finished) {
                _selectedNumber += 1;
            }
        }];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark 表情键盘数据源和代理
//选中表情后
- (void)emojiKeyBoardView:(AGEmojiKeyboardView *)emojiKeyBoardView didUseEmoji:(NSString *)emoji {
    self.textView.text = [self.textView.text stringByAppendingString:emoji];
    self.navigationItem.rightBarButtonItem.enabled = YES;
}
//点击删除按钮
- (void)emojiKeyBoardViewDidPressBackSpace:(AGEmojiKeyboardView *)emojiKeyBoardView {
    [self.textView deleteBackward];
}
//删除按钮的图片
- (UIImage *)backSpaceButtonImageForEmojiKeyboardView:(AGEmojiKeyboardView *)emojiKeyboardView {
    UIImage *img = [self randomImage];
    [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    return img;
}

//生成随机色
- (UIColor *)randomColor {
    return [UIColor colorWithRed:drand48()
                           green:drand48()
                            blue:drand48()
                           alpha:drand48()];
}
//生成长方形图片,颜色随机
- (UIImage *)randomImage {
    CGSize size = CGSizeMake(30, 10);
    UIGraphicsBeginImageContextWithOptions(size , NO, 0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *fillColor = [self randomColor];
    CGContextSetFillColorWithColor(context, [fillColor CGColor]);
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    CGContextFillRect(context, rect);
    
    fillColor = [self randomColor];
    CGContextSetFillColorWithColor(context, [fillColor CGColor]);
    CGFloat xxx = 3;
    rect = CGRectMake(xxx, xxx, size.width - 2 * xxx, size.height - 2 * xxx);
    CGContextFillRect(context, rect);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
//当前选中系列的标题图片
- (UIImage *)emojiKeyboardView:(AGEmojiKeyboardView *)emojiKeyboardView imageForSelectedCategory:(AGEmojiKeyboardViewCategoryImage)category {
    UIImage *img = [self randomImage];
    [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    return img;
}
//未选中状态的标题图片
- (UIImage *)emojiKeyboardView:(AGEmojiKeyboardView *)emojiKeyboardView imageForNonSelectedCategory:(AGEmojiKeyboardViewCategoryImage)category {
    UIImage *img = [self randomImage];
    [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    return img;
}
@end
