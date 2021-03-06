//
//  ViewController.swift
//  scrollingNotationv4
//
//  Created by brendan woods on 2016-02-10.
//  Copyright © 2016 brendan woods. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase

class GameViewController: UIViewController , AVAudioPlayerDelegate{
    
    @IBOutlet weak var blankStaff:BlankStaff!
    @IBOutlet weak var aButton:UIButton?
    @IBOutlet weak var bButton:UIButton?
    @IBOutlet weak var cButton:UIButton?
    @IBOutlet weak var dButton:UIButton?
    @IBOutlet weak var eButton:UIButton?
    @IBOutlet weak var fButton:UIButton?
    @IBOutlet weak var gButton:UIButton?
    @IBOutlet weak var scoreLabel:UILabel?
    @IBOutlet weak var highScoreLabel:UILabel?
    @IBOutlet weak var scoreToBeatLabel:UILabel!
    @IBOutlet weak var grandStaffView: UIImageView!
    
    var ovalNoteImageView = UIImageView()
    var noteImageView = UIImageView()
    
    var scoresArray:NSMutableArray!
    
    let topLineY:CGFloat = 100
    var screenWidth:CGFloat = 0
    var distanceToMoveNoteLeft:CGFloat = 0
    let fractionOfTheScreenToMoveNote = 320
    let ovalNoteWidth:CGFloat = 30
    let ovalNoteHeight:CGFloat = 20
    var noteImageWidth:CGFloat = 0
    var noteImageHeight:CGFloat = 0
    
    let spaceBetweenNotes:CGFloat = 10
    var timer = NSTimer()
    var noteLibrary = NoteLibrary()
    var gameOver = false
    var currentScrollSpeed:NSTimeInterval = 0.02
    var startingScrollSpeed:NSTimeInterval = 0.02
    var currentNote: (noteName: String,octaveNumber: Int,
        absoluteNote: Int, isFlatOrSharp:Bool,diffFromTop:Int) = ("",0,0,false,0)
    var currentScore = 0
    var nextScoreIncrease = 0
    let scoreIncreaseConstant = 100
    var scoresNeedResetting = false
    var difficulty = ""
    var notePlayer: AVAudioPlayer! = nil
    var appDelegate = AppDelegate()
    var multiplayerData = MultiplayerGamesTableViewController.gameData()
    var isMultiplayer = false
    var scoreHasBeenSentToFirebase = false;
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        screenWidth = UIScreen.mainScreen().bounds.width
        distanceToMoveNoteLeft = screenWidth / CGFloat(fractionOfTheScreenToMoveNote)
        formatButtonShapes()
        noteLibrary.fillNoteLibrary()
        noteLibrary.filterNotesForDifficulty(difficulty)
    }
    
    
    override func viewDidAppear(animated: Bool) {
        noteImageHeight = grandStaffView.frame.size.height
        noteImageWidth = noteImageHeight/8.333
        
        gameLoop()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func postScoreToFirebase() {
        let defaults = NSUserDefaults()
        let highScoresRef = Firebase(url: "https://glowing-torch-8861.firebaseio.com/High%20Scores")
        
        let uid = defaults.valueForKey("FirebaseUID")
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let theScore = currentScore
        let score1 = ["Score" : theScore, "Name" : defaults.valueForKey("FirebaseUsername")!, "UUID" : appDelegate.UUID, "Date": NSDate().timeIntervalSince1970, "UID": uid!]
        let autoId = highScoresRef.childByAutoId()
        autoId.setValue(score1, andPriority: 0 - Int(theScore))
        let autoIdKey = autoId.key
        
        let ref = Firebase(url: "https://glowing-torch-8861.firebaseio.com/Usernames/\(defaults.valueForKey("FirebaseUsername")!)/scores")
        
        ref.updateChildValues([autoIdKey: currentScore])
        
    }
    
    
    func gameLoop() {
        
        setHighScore()
        
        if isMultiplayer && multiplayerData.isNewGame != true {
            scoreToBeatLabel?.hidden = false
            scoreToBeatLabel.text = "Score To Beat: \(multiplayerData.scoreToBeat)"
        }
        else {
            scoreToBeatLabel.hidden = true
        }
        
        
        if scoresNeedResetting
        {
            currentScore = 0
            scoreLabel!.text = String(currentScore)
            scoresNeedResetting = false
        }
        
        currentNote = noteLibrary.returnRandomNote()
        scoreHasBeenSentToFirebase = false
        createNoteImage(currentNote)
        
    }
    
    
    func setHighScore() {
        appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        highScoreLabel!.text = "High Score: \(appDelegate.highScore)"
    }
    
    
    func formatButtonShapes() {
        let buttonRadius:CGFloat = 5
        aButton?.layer.cornerRadius = buttonRadius
        bButton?.layer.cornerRadius = buttonRadius
        cButton?.layer.cornerRadius = buttonRadius
        dButton?.layer.cornerRadius = buttonRadius
        eButton?.layer.cornerRadius = buttonRadius
        fButton?.layer.cornerRadius = buttonRadius
        gButton?.layer.cornerRadius = buttonRadius
    }
    
    
    func createNoteImage(note: (noteName: String,octaveNumber: Int,
        absoluteNote: Int, isFlatOrSharp:Bool,diffFromTop:Int)) {
        
        //need navigation bar and status height to compensate for positioning of note
        let navHeight:CGFloat = (self.navigationController?.navigationBar.frame.height)!
        
        let statusHeight:CGFloat = UIApplication.sharedApplication().statusBarFrame.size.height
        
        let imageName = "\(note.absoluteNote).png"
        let image = UIImage(named: imageName)
        noteImageView = UIImageView(image: image!)
        
        noteImageView.frame = CGRectMake(
            screenWidth,
            grandStaffView.frame.origin.y + navHeight + statusHeight,
            noteImageWidth,
            noteImageHeight)
        
        //ff the sound option is true, play note sound.
        if appDelegate.isSound {
            let path = NSBundle.mainBundle().pathForResource("\(note.absoluteNote)", ofType: "mp3")
            let fileUrl = NSURL(fileURLWithPath: (path)!)
            notePlayer = try? AVAudioPlayer(contentsOfURL: fileUrl)
            notePlayer.prepareToPlay()
            notePlayer.delegate = self
            notePlayer.play()
        }
        
        view.addSubview(noteImageView)
        
        timer = NSTimer.scheduledTimerWithTimeInterval(currentScrollSpeed, target: self,
                                                       selector: #selector(GameViewController.moveNoteLeft), userInfo: nil, repeats: true)
    }
    
    
    func moveNoteLeft(){
        if noteImageView.center.x <= 0 {
            currentScrollSpeed = startingScrollSpeed
            gameOver = true
            scoresNeedResetting = true
            timer.invalidate()
            gameOverAlert()
        } else {
            self.noteImageView.center.x -= distanceToMoveNoteLeft
        }
    }
    
    func correctGuess() {
        self.noteImageView.removeFromSuperview()
        timer.invalidate()
        currentScrollSpeed /= 1.1
        currentScore += 1
        scoreLabel!.text = String(currentScore)
        gameLoop()
        
    }
    
    func incorrectGuess() {
        gameOver = true
        timer.invalidate()
        currentScrollSpeed = startingScrollSpeed
        scoresNeedResetting = true
        gameOverAlert()
    }
    
    
    func gameOverAlert(){
        appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        
        //some scores have been double posting. In order to protect from an incorrect guess and the 
        //not crossing the end line in the same line resulting in the score being posted multiple times,
        //check to see if the score has been posted. if it hasn't  , post it. 
        if scoreHasBeenSentToFirebase == false {
            scoreHasBeenSentToFirebase = true
            postScoreToFirebase()
        }
        
        
        if isMultiplayer == false {
            var alert = UIAlertController()
            if currentScore > appDelegate.highScore {
                alert = UIAlertController(title: "Game Over", message: "NEW HIGH SCORE! \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
                appDelegate.highScore = currentScore
            }
            else {
                alert = UIAlertController(title: "Game Over", message: "The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
            }
            alert.addAction(UIAlertAction(title: "New Game", style: UIAlertActionStyle.Default, handler: {
                action in
                self.noteImageView.removeFromSuperview()
                self.gameLoop()
            }))
            
            alert.addAction(UIAlertAction(title: "Main Menu", style: UIAlertActionStyle.Default, handler: {
                action in
                self.navigationController?.popToRootViewControllerAnimated(true)
            }))
            
            self.presentViewController(alert, animated: true, completion: nil)
        }
        else {
            multiplayerGameOver()
        }
    }
    
    func multiplayerGameOver() {
        let gameRef = Firebase(url: "https://glowing-torch-8861.firebaseio.com/Games/\(multiplayerData.gameID)")
        
        if multiplayerData.isNewGame == false{
            //check if player beat opponent
            if currentScore > multiplayerData.scoreToBeat {
                //update player wins
                multiplayerData.heroWins += 1
                gameRef.childByAppendingPath("/wins/").updateChildValues([multiplayerData.hero : multiplayerData.heroWins])
            }
            else if currentScore < multiplayerData.scoreToBeat{
                //update opponent wins
                multiplayerData.opponentWins += 1
                gameRef.childByAppendingPath("/wins/").updateChildValues([multiplayerData.opponent : multiplayerData.opponentWins])
            }
            
            //display alerts
            var alert = UIAlertController()
            
            //if high score
            if currentScore > appDelegate.highScore {
                //if high score and win
                if currentScore > multiplayerData.scoreToBeat{
                    alert = UIAlertController(title: "Game Over", message: "NEW HIGH SCORE! \n YOU WIN! \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
                    appDelegate.highScore = currentScore
                }
                //if high score and loss
                if currentScore < multiplayerData.scoreToBeat{
                    alert = UIAlertController(title: "Game Over", message: "NEW HIGH SCORE! \n You Lost \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
                    appDelegate.highScore = currentScore
                }
                if currentScore == multiplayerData.scoreToBeat{
                    alert = UIAlertController(title: "Game Over", message: "NEW HIGH SCORE! \n YOU TIED! \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
                    appDelegate.highScore = currentScore
                }
            }
                //if win
            else if currentScore > multiplayerData.scoreToBeat {
                alert = UIAlertController(title: "Game Over", message: "YOU WIN! \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
            }
                //if loss
            else if currentScore < multiplayerData.scoreToBeat {
                alert = UIAlertController(title: "Game Over", message: "You Lost \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
            }
                
                //if tie
            else if currentScore == multiplayerData.scoreToBeat {
                alert = UIAlertController(title: "Game Over", message: "YOU TIED! \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore)", preferredStyle: .Alert)
            }
            
            
            alert.addAction(UIAlertAction(title: "Start New Game", style: UIAlertActionStyle.Default, handler: {
                action in
                self.noteImageView.removeFromSuperview()
                self.multiplayerData.isNewGame = true
                self.gameLoop()
            }))
            
            //update score to beat to 0
            multiplayerData.scoreToBeat = 0
            gameRef.updateChildValues(["scoreToBeat": 0])
            
            //change the waitingOnPlayer
            multiplayerData.waitingOnPlayer = multiplayerData.opponent
            gameRef.childByAppendingPath("/waitingOnPlayer").setValue([multiplayerData.opponent : true])
            
            //change isNewGame to true
            multiplayerData.isNewGame = true
            gameRef.updateChildValues(["isNewGame" : false])
            
            self.presentViewController(alert, animated: true, completion: nil)
            
        }
            
            //if it is the first score of the round
        else if multiplayerData.isNewGame == true {
            
            //post the score to beat to firebase
            gameRef.updateChildValues(["scoreToBeat" : currentScore])
            //change the waiting on player
            gameRef.childByAppendingPath("/waitingOnPlayer").setValue([multiplayerData.opponent : true])
            //change the isnewgame
            gameRef.updateChildValues(["isNewGame" : false])
            
            
            //see if the next player's device has a token. if so , add to queue
            let awaitingToken = Firebase(url: "https://glowing-torch-8861.firebaseio.com/Usernames/\(multiplayerData.opponent)/token")
            
            awaitingToken.observeSingleEventOfType(.Value, withBlock: { snap in
                
                if snap.value is NSNull {
                    print("next player has no token. Not being added to push queue.")
                } else {
                    
                    let queueRef = Firebase(url: "https://glowing-torch-8861.firebaseio.com/Queue")
                    let newItemRef = queueRef.childByAutoId()
                    let token = snap.value
                    print("the token is \(token)")
                    
                    let newItem = [
                        "player": self.multiplayerData.opponent,
                        "opponent": self.multiplayerData.hero,
                        "token": token]
                    
                    newItemRef.setValue(newItem)
                    
                }
            })
            
            
            
            
            
            //display alerts
            var alert = UIAlertController()
            
            //if high score
            if currentScore > appDelegate.highScore {
                alert = UIAlertController(title: "Game Over", message: "NEW HIGH SCORE! \n The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore) \n \(multiplayerData.opponent)'s turn", preferredStyle: .Alert)
                appDelegate.highScore = currentScore
            }
                //else display posted score
            else {
                alert = UIAlertController(title: "Game Over", message: "The note was :  \(currentNote.noteName.uppercaseString) \n You scored : \(currentScore) \n \(multiplayerData.opponent)'s turn", preferredStyle: .Alert)
            }
            alert.addAction(UIAlertAction(title: "Main Menu", style: UIAlertActionStyle.Default, handler: {
                action in
                self.navigationController?.popToRootViewControllerAnimated(true)
            }))
            
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
    }
    
    @IBAction func noteButtonPushed(sender:UIButton) {
        
        if sender.titleLabel!.text!.lowercaseString == currentNote.noteName {
            // animate a color change of the key pushed
            sender.backgroundColor = UIColor.greenColor()
            UIView.animateWithDuration(0.3, animations: {
                sender.backgroundColor = UIColor.whiteColor()
            })
            correctGuess()
        }else {
            incorrectGuess()
            // animate a color change of the key pushed
            sender.backgroundColor = UIColor.redColor()
            UIView.animateWithDuration(0.3, animations: {
                sender.backgroundColor = UIColor.whiteColor()
            })
        }
    }
    
}


