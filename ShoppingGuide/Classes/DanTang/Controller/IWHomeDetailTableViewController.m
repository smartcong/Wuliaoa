//
//  IWHomeDetailTableViewController.m
//  Wuliaoa
//
//  Created by 白洪坤 on 2017/3/9.
//  Copyright © 2017年 itcast. All rights reserved.
//

#import "IWHomeDetailTableViewController.h"
#import "IWStatus.h"
#import "IWStatusFrame.h"
#import "IWStatusCell.h"
#import "IWCommitCell.h"
#import "IWStatusToolbar.h"

#import "LYNetworkTool.h"
#import "IWAccount.h"
#import "IWAccountTool.h"
#import "MBProgressHUD+MJ.h"
#import "IWWeiboTool.h"
#import "IWCommit.h"
#import "MJExtension.h"
#import "IWPhoto.h"

#import "MessageTextView.h"

#import <LoremIpsum/LoremIpsum.h>

#define DEBUG_CUSTOM_TYPING_INDICATOR 0
#define DEBUG_CUSTOM_BOTTOM_VIEW 0

typedef enum _InputType
{
    InputType_Text     = 0,
    InputType_Emoji    = 1,
} InputType;
static NSString* commitCell = @"commitCell";
@interface IWHomeDetailTableViewController ()<AGEmojiKeyboardViewDelegate, AGEmojiKeyboardViewDataSource>{
       AGEmojiKeyboardView *_emojiKeyboardView;
}
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSArray *commentArray;
@property (nonatomic, strong) UIWindow *pipWindow;
@property (nonatomic, assign) InputType growingInputType;
@end

@implementation IWHomeDetailTableViewController

- (instancetype)init
{
    self = [super initWithTableViewStyle:UITableViewStylePlain];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

+ (UITableViewStyle)tableViewStyleForCoder:(NSCoder *)decoder
{
    return UITableViewStylePlain;
}

- (void)commonInit
{
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [self registerClassForTextView:[MessageTextView class]];
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([IWCommitCell class]) bundle:nil] forCellReuseIdentifier:commitCell];

}

/**
 *  表情
 */
- (void)openEmotion
{
    if (_growingInputType == InputType_Text) {
        [self.textView resignFirstResponder];
        self.textView.inputView = _emojiKeyboardView;
        [self.textView becomeFirstResponder];
        self.growingInputType = InputType_Emoji;
    } else if (_growingInputType == InputType_Emoji) {
        [self.textView resignFirstResponder];
        self.textView.inputView = nil;
        [self.textView becomeFirstResponder];
        self.growingInputType = InputType_Text;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.bounces = YES;
    self.shakeToClearEnabled = YES;
    self.keyboardPanningEnabled = YES;
    self.shouldScrollToBottomAfterKeyboardShows = NO;
    self.inverted = NO;
    
    [self.rightButton setTitle:@"发送" forState:UIControlStateNormal];
    
    [self.leftButton setImage:[UIImage imageNamed:@"compose_emoticonbutton_background_os7"] forState:UIControlStateNormal];
    [self.leftButton setTintColor:[UIColor grayColor]];
    
    self.textInputbar.autoHideRightButton = YES;
    self.textInputbar.maxCharCount = 24;
    self.textInputbar.counterStyle = SLKCounterStyleSplit;
    self.textInputbar.counterPosition = SLKCounterPositionTop;
    [self.textInputbar.editorTitle setTextColor:[UIColor darkGrayColor]];
    [self.textInputbar.editorLeftButton setTintColor:[UIColor colorWithRed:0.0/255.0 green:122.0/255.0 blue:255.0/255.0 alpha:1.0]];
    [self.textInputbar.editorRightButton setTintColor:[UIColor colorWithRed:0.0/255.0 green:122.0/255.0 blue:255.0/255.0 alpha:1.0]];
    [self getComment];
    
    _growingInputType = InputType_Text;
    //创建键盘
    AGEmojiKeyboardView *emojiKeyboardView = [[AGEmojiKeyboardView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 216) dataSource:self];
    emojiKeyboardView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    emojiKeyboardView.delegate = self;
    _emojiKeyboardView = emojiKeyboardView;
}



- (void)setStatusFrame:(IWStatusFrame *)statusFrame{
    _statusFrame = statusFrame;
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1+ _commentArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        // 1.创建cell
        IWStatusCell *cell = [IWStatusCell cellWithTableView:tableView];
        
        // 2.传递frame模型
        cell.statusFrame = _statusFrame;
        cell.statusToolbar.btnblock = ^(){
            [self getComment];
        };
        return cell;
    }else{
        IWCommitCell *cell = [tableView dequeueReusableCellWithIdentifier:commitCell];
        IWCommit *commit = _commentArray[indexPath.row - 1];
        cell.commit = commit;
        return cell;
    }
    
    
    
}

#pragma mark - 代理方法
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        IWStatusFrame *statusFrame = _statusFrame;
        return statusFrame.cellHeight;
    }else{
        // 1.取出这行微博的内容
        IWCommit *commit = _commentArray[indexPath.row - 1];
        // 2.计算微博内容大小占据的高度
        NSString *text = commit.content;
        CGFloat textHeight  = [text sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(250,MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
        // sizeWithFont: 根据字体来算text的宽高
        // constrainedToSize: 限制算出来的文集的宽度和高度 这里限制宽度为250个像素点
        // lineBreakMode: 换行的模式
        // 设置cell的高度
        return  textHeight < 55 ? 55 : textHeight + 5;
    }
    
}


//发送评论按钮
- (void)didPressRightButton:(id)sender
{
    [self.textView refreshFirstResponder];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    IWAccount *account = [IWAccountTool account];
    params[@"userId"] = account.id;
    params[@"content"] = self.textView.text;
    NSString *articleId = _statusFrame.status.id;
    NSString *URLString = [NSString stringWithFormat:@"%@/comment/%@",IWAPPURL,articleId];

    [[LYNetworkTool sharedNetworkTool] loadDataInfoPost:URLString parameters:params success:^(id  _Nullable responseObject) {
        [self getComment];
        [self.textView resignFirstResponder];
    } failure:^(NSError * _Nullable error) {
        
    }];
    [super didPressRightButton:sender];
}


- (void)didPressLeftButton:(id)sender{
    [self openEmotion];
    [super didPressLeftButton:sender];
}
//获取评论
- (void)getComment{
    NSString *articleId = _statusFrame.status.id;
    NSString *URLString = [NSString stringWithFormat:@"%@/comment/%@/1/10",IWAPPURL,articleId];

    [[LYNetworkTool sharedNetworkTool] loadDataInfo:URLString parameters:nil success:^(id  _Nullable responseObject) {
        IWLog(@"评论————————%@",responseObject[@"result"]);
        _commentArray = [IWCommit mj_objectArrayWithKeyValuesArray:responseObject[@"result"][@"list"]];
        [self getarticle];
        
    } failure:^(NSError * _Nullable error) {
        
    }];
}
//根据id获取最新辣条
- (void)getarticle{
    NSString *articleId = _statusFrame.status.id;
    NSString *URLString = [NSString stringWithFormat:@"%@/%@",IWArticleURL,articleId];
    [[LYNetworkTool sharedNetworkTool] loadDataInfo:URLString parameters:nil success:^(id  _Nullable responseObject) {
        IWLog(@"最新辣条————————%@",responseObject);
        // Tell MJExtension what type model will be contained in IWPhoto.
        [IWStatus mj_setupObjectClassInArray:^NSDictionary *{
            return @{@"images" : [IWPhoto class]};
        }];
        // 将字典数组转为模型数组(里面放的就是IWStatus模型)
        NSArray *responseObjectArray = [NSArray arrayWithObject:responseObject];
        NSArray *statusArray = [IWStatus mj_objectArrayWithKeyValuesArray:responseObjectArray];
        // 创建frame模型对象
        for (IWStatus *status in statusArray) {
            // 传递微博模型数据
            _statusFrame.status.likeCount = status.likeCount;
            _statusFrame.status.hateCount = status.hateCount;
            _statusFrame.status.commentCount = status.commentCount;

            [self.tableView reloadData];
        }
        
    } failure:^(NSError * _Nullable error) {
        
    }];

}

#pragma mark 表情键盘数据源和代理
//选中表情后
- (void)emojiKeyBoardView:(AGEmojiKeyboardView *)emojiKeyBoardView didUseEmoji:(NSString *)emoji {
    self.textView.text = [self.textView.text stringByAppendingString:emoji];
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
    UIImage *img = [UIImage imageNamed:@"content-details_like_selected_16x16_"];
    [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    return img;
}
//未选中状态的标题图片
- (UIImage *)emojiKeyboardView:(AGEmojiKeyboardView *)emojiKeyboardView imageForNonSelectedCategory:(AGEmojiKeyboardViewCategoryImage)category {
    UIImage *img = [UIImage imageNamed:@"content-details_like_selected_16x16_"];
    [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    return img;
}

@end
