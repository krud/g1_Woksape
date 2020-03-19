import CoreMotion
import SpriteKit
import GameplayKit

enum CollisionTypes: UInt32 {
    case player = 1
    case wall = 2
    case succulent = 4
    case blackHole = 8
    case portal = 16
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: SKSpriteNode!
    var lastTouchPosition: CGPoint?

    var motionManager: CMMotionManager!

    var nextLevel =  false
    var isGameOver = false
    var scoreLabel: SKLabelNode!
    var levelLabel: SKLabelNode!
    
    var succs: Int = 0
    
    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var level = 1 {
        didSet {
            levelLabel.text = "Level: \(level)"
        }
    }

    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "background.jpg")
        background.position = CGPoint(x: 284, y: 170)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)

        scoreLabel = SKLabelNode(fontNamed: "Futura")
        scoreLabel.text = "Score: 0"
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 8, y: 4)
        addChild(scoreLabel)
        
        levelLabel = SKLabelNode(fontNamed: "Futura")
        levelLabel.text = "Level: 1"
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: 280, y: 4)
        addChild(levelLabel)

        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self

        startLevel()
    }
    
    func startLevel() {
        loadLevel()
        createPlayer()
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
    }

    func loadLevel() {
        if let levelPath = Bundle.main.path(forResource: "level\(level)", ofType: "txt") {
            if let levelString = try? String(contentsOfFile: levelPath) {
                let lines = levelString.components(separatedBy: "\n")

                for (row, line) in lines.reversed().enumerated() {
                    for (column, letter) in line.enumerated() {
                        let position = CGPoint(x: (32 * column) + 18, y: (32 * row) + 18)

                        if letter == "w" {
                            let node = SKSpriteNode(imageNamed: "wall")
                            node.position = position
                            node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
                            node.physicsBody?.categoryBitMask = CollisionTypes.wall.rawValue
                            node.physicsBody?.isDynamic = false
                            addChild(node)
                        } else if letter == "b"  {
                            let node = SKSpriteNode(imageNamed: "blackHole")
                            node.name = "blackHole"
                            node.position = position
                            node.run(SKAction.repeatForever(SKAction.rotate(byAngle: CGFloat.pi, duration: 1)))
                            node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
                            node.physicsBody?.isDynamic = false

                            node.physicsBody?.categoryBitMask = CollisionTypes.blackHole.rawValue
                            node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
                            node.physicsBody?.collisionBitMask = 0
                            addChild(node)
                        } else if letter == "s"  {
                            succs += 1
                            let node = SKSpriteNode(imageNamed: "succulent")
                            node.name = "succulent"
                            node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
                            node.physicsBody?.isDynamic = false

                            node.physicsBody?.categoryBitMask = CollisionTypes.succulent.rawValue
                            node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
                            node.physicsBody?.collisionBitMask = 0
                            node.position = position
                            addChild(node)
                        } else if letter == "p"  {
                            let node = SKSpriteNode(imageNamed: "portal")
                            node.name = "portal"
                            node.physicsBody = SKPhysicsBody(circleOfRadius: node.size.width / 2)
                            node.physicsBody?.isDynamic = false

                            node.physicsBody?.categoryBitMask = CollisionTypes.portal.rawValue
                            node.physicsBody?.contactTestBitMask = CollisionTypes.player.rawValue
                            node.physicsBody?.collisionBitMask = 0
                            node.position = position
                            addChild(node)
                        }
                    }
                }
            }
        }
    }

    func createPlayer() {
        player = SKSpriteNode(imageNamed: "player")
        player.position = CGPoint(x: 43, y: 270)
        player.physicsBody = SKPhysicsBody(circleOfRadius: player.size.width / 2)
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.linearDamping = 0.5

        player.physicsBody?.categoryBitMask = CollisionTypes.player.rawValue
        player.physicsBody?.contactTestBitMask = CollisionTypes.succulent.rawValue | CollisionTypes.blackHole.rawValue | CollisionTypes.portal.rawValue
        player.physicsBody?.collisionBitMask = CollisionTypes.wall.rawValue
        addChild(player)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            lastTouchPosition = location
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            lastTouchPosition = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPosition = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPosition = nil
    }

    override func update(_ currentTime: TimeInterval) {
        guard isGameOver == false else { return }
        #if targetEnvironment(simulator)
            if let currentTouch = lastTouchPosition {
                let diff = CGPoint(x: currentTouch.x - player.position.x, y: currentTouch.y - player.position.y)
                physicsWorld.gravity = CGVector(dx: diff.x / 100, dy: diff.y / 100)
            }
        #else
            if let accelerometerData = motionManager.accelerometerData {
                physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.y * -50, dy: accelerometerData.acceleration.x * 50)
            }
        #endif
    }

    func didBegin(_ contact: SKPhysicsContact) {
        if contact.bodyA.node == player {
            playerCollided(with: contact.bodyB.node!)
        } else if contact.bodyB.node == player {
            playerCollided(with: contact.bodyA.node!)
        }
    }

    func playerCollided(with node: SKNode) {
        if node.name == "blackHole" {
            player.physicsBody?.isDynamic = false
            isGameOver = true
            score -= 1

            let move = SKAction.move(to: node.position, duration: 0.25)
            let scale = SKAction.scale(to: 0.0001, duration: 0.25)
            let remove = SKAction.removeFromParent()
            let sequence = SKAction.sequence([move, scale, remove])

            player.run(sequence) { [unowned self] in
                self.createPlayer()
                self.isGameOver = false
            }
        } else if node.name == "succulent" {
            node.removeFromParent()
            score += 1
            succs -= 1
        } else if node.name == "portal" {
            
            if (succs == 0) {
                player.physicsBody?.isDynamic = false
                let move = SKAction.move(to: node.position, duration: 0.25)
                let scale = SKAction.scale(to: 0.0001, duration: 0.25)
                let remove = SKAction.removeFromParent()
                let sequence = SKAction.sequence([move, scale, remove])

                player.run(sequence) { [unowned self] in
                    self.isGameOver = false
                }
                self.removeAllChildren()
                if (level != 5){
                    level += 1
                    score += 8
                    startLevel()
                    rerenderLevel()
                } else {
                    print("gameover")
                    gameOverScene()
                }
            }
        }
    }
    
    func rerenderLevel(){
        let background = SKSpriteNode(imageNamed: "background.jpg")
        background.position = CGPoint(x: 284, y: 170)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        scoreLabel = SKLabelNode(fontNamed: "Futura")
        scoreLabel.text = "Score: \(score)"
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 8, y: 4)
        addChild(scoreLabel)
        
        levelLabel = SKLabelNode(fontNamed: "Futura")
        levelLabel.text = "Level: \(level)"
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: 280, y: 4)
        addChild(levelLabel)

        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
    }
    
    func gameOverScene(){
        let background = SKSpriteNode(imageNamed: "background.jpg")
        background.position = CGPoint(x: 284, y: 170)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        let endLabel = SKLabelNode(fontNamed: "Futura-Bold")
        endLabel.text = "Game Over"
        endLabel.horizontalAlignmentMode = .center
        endLabel.position = CGPoint(x: 284, y: 170)
        addChild(endLabel)
    }
}
 
