import 'package:flutter/material.dart';
import 'dart:ui';  // Add this import for ImageFilter
import 'dart:math'; // Add this import for sin function

// Add these enums at the top of the file
enum Suit { hearts, diamonds, clubs, spades }
enum Rank { ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king }

class Card {
  final Suit suit;
  final Rank rank;
  final bool isRed;

  Card(this.suit, this.rank) : isRed = suit == Suit.hearts || suit == Suit.diamonds;

  String get rankString {
    switch (rank) {
      case Rank.ace: return 'A';
      case Rank.jack: return 'J';
      case Rank.queen: return 'Q';
      case Rank.king: return 'K';
      default: return (rank.index + 1).toString();
    }
  }

  String get suitString {
    switch (suit) {
      case Suit.hearts: return '♥';
      case Suit.diamonds: return '♦';
      case Suit.clubs: return '♣';
      case Suit.spades: return '♠';
    }
  }
}

void main() {
  runApp(const SolitaireApp());
}

class SolitaireApp extends StatelessWidget {
  const SolitaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solitaire',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutBack,
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const GameBoard(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[800],
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotateAnimation.value * 3.14159,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayingCard(
                      card: Card(Suit.hearts, Rank.ace),
                      isFaceUp: true,
                    ),
                    const SizedBox(width: 8),
                    PlayingCard(
                      card: Card(Suit.spades, Rank.king),
                      isFaceUp: true,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late List<List<Card>> tableauPiles;
  late List<Card> deck;
  List<Card> wastePile = [];
  List<List<bool>> revealedCards = List.generate(7, (_) => []);
  List<List<Card>> foundationPiles = List.generate(4, (_) => []);
  Map<String, int>? draggedCard;
  bool showWinAnimation = false;
  bool isDealing = false;
  List<AnimationController> dealingControllers = [];
  List<Animation<Offset>> dealingAnimations = [];
  List<Card> cardsToAnimate = [];
  List<bool> cardsFaceUp = [];
  late TableauLayoutInfo layoutInfo;

  @override
  void initState() {
    super.initState();
    initializeGame();
  }

  void initializeGame() {
    // Create and shuffle the deck
    deck = [];
    for (var suit in Suit.values) {
      for (var rank in Rank.values) {
        deck.add(Card(suit, rank));
      }
    }
    deck.shuffle();

    // Initialize tableau piles and revealed cards
    tableauPiles = List.generate(7, (index) => []);
    revealedCards = List.generate(7, (index) => []); 
    foundationPiles = List.generate(4, (_) => []);

    // Prepare cards for animation
    cardsToAnimate = [];
    cardsFaceUp = [];
    int totalCards = 28; // Sum of cards 1+2+3+4+5+6+7
    
    // Create animation controllers and animations
    for (var controller in dealingControllers) {
      controller.dispose();
    }
    dealingControllers = [];
    dealingAnimations = [];

    // Calculate card positions and create animations
    for (int i = 0; i < totalCards; i++) {
      var card = deck.removeLast();
      cardsToAnimate.add(card);
      
      // Calculate which pile this card belongs to and its position in the pile
      int pileIndex = 0;
      int cardPositionInPile = 0;
      int tempCount = i;
      while (tempCount >= 0) {
        pileIndex++;
        tempCount -= pileIndex;
      }
      pileIndex--;
      cardPositionInPile = i - ((pileIndex * (pileIndex + 1)) ~/ 2);
      
      // Calculate if card should be face up (only the top card of each pile)
      bool isFaceUp = cardPositionInPile == pileIndex;
      cardsFaceUp.add(isFaceUp);

      var controller = AnimationController(
        duration: const Duration(milliseconds: 600),  // Faster animation
        vsync: this,
      );
      
      dealingControllers.add(controller);
      
      // Create a curved animation path
      dealingAnimations.add(
        TweenSequence<Offset>([
          TweenSequenceItem(
            tween: Tween<Offset>(
              begin: const Offset(0, 0),
              end: Offset(pileIndex.toDouble() * 0.3, -2.0), // Initial upward arc
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 30.0,
          ),
          TweenSequenceItem(
            tween: Tween<Offset>(
              begin: Offset(pileIndex.toDouble() * 0.3, -2.0),
              end: Offset(pileIndex.toDouble() * 0.7, -2.5), // Peak of arc
            ).chain(CurveTween(curve: Curves.linear)),
            weight: 30.0,
          ),
          TweenSequenceItem(
            tween: Tween<Offset>(
              begin: Offset(pileIndex.toDouble() * 0.7, -2.5),
              end: Offset(pileIndex.toDouble(), cardPositionInPile.toDouble()), // Land in final position
            ).chain(CurveTween(curve: Curves.easeInOutBack)),
            weight: 40.0,
          ),
        ]).animate(controller),
      );
    }

    // Start dealing animation
    isDealing = true;
    dealCards();
  }

  void dealCards() async {
    // Shorter initial delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Deal cards one by one with a shorter delay
    for (int i = 0; i < dealingControllers.length; i++) {
      if (!mounted) return;
      
      dealingControllers[i].forward();
      
      // Much shorter delay between each card for a snappier feel
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Wait for all animations to complete
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    setState(() {
      isDealing = false;
      // Deal the cards to their final positions
      int cardIndex = 0;
      for (int pile = 0; pile < 7; pile++) {
        for (int j = 0; j <= pile; j++) {
          tableauPiles[pile].add(cardsToAnimate[cardIndex]);
          revealedCards[pile].add(cardsFaceUp[cardIndex]);
          cardIndex++;
        }
      }
    });
  }

  // Add this getter for the foundation suit order
  List<Suit> get foundationSuitOrder => [Suit.clubs, Suit.spades, Suit.hearts, Suit.diamonds];

  void drawCard() {
    setState(() {
      if (deck.isEmpty) {
        if (wastePile.isEmpty) return; // Do nothing if both piles are empty
        // Keep the same order as in waste pile
        deck = List.from(wastePile);
        wastePile.clear();
      } else {
        wastePile.insert(0, deck.removeLast());
      }
    });
  }

  void revealCard(int pileIndex) {
    if (pileIndex < tableauPiles.length && 
        tableauPiles[pileIndex].isNotEmpty) {
      // Only reveal if clicking on the top card and it's face down
      int topCardIndex = tableauPiles[pileIndex].length - 1;
      if (!revealedCards[pileIndex][topCardIndex]) {
        setState(() {
          revealedCards[pileIndex][topCardIndex] = true;
        });
      }
    }
  }

  // Update the canDragCard check to allow dragging from any revealed card
  bool canDragCard(int pileIndex, int cardIndex) {
    // Can drag if:
    // 1. The card is revealed AND
    // 2. All cards above it are also revealed
    if (!revealedCards[pileIndex][cardIndex]) return false;
    
    // Check if all cards above are revealed
    for (int i = cardIndex; i < tableauPiles[pileIndex].length; i++) {
      if (!revealedCards[pileIndex][i]) return false;
    }
    return true;
  }

  // Update the canDropCard method to properly handle empty spots
  bool canDropCard(Card draggedCard, Card? targetCard) {
    if (targetCard == null) {
      return true; // Allow any card to be placed on empty spots
    }
    
    // Check if cards are alternate colors and sequential
    return draggedCard.isRed != targetCard.isRed && 
           draggedCard.rank.index == targetCard.rank.index - 1;
  }

  // Update handleCardDrop to handle stacks
  void handleCardDrop(Map<String, dynamic> dragData, int targetPileIndex) {
    final sourcePileIndex = dragData['pile'] as int;
    final sourceCardIndex = dragData['index'] as int;
    
    // Handle waste pile differently
    if (sourcePileIndex == -1) {
      final draggedCard = wastePile.first;
      final targetCard = tableauPiles[targetPileIndex].isNotEmpty ? 
                      tableauPiles[targetPileIndex].last : null;
      
      if (canDropCard(draggedCard, targetCard)) {
        setState(() {
          // Move card from waste pile to tableau
          tableauPiles[targetPileIndex].add(wastePile.removeAt(0));
          revealedCards[targetPileIndex].add(true);  // New card is always revealed
        });
      }
      return;
    }

    // Handle foundation piles
    if (sourcePileIndex <= -2) {  // Foundation pile indices are -2, -3, -4, -5
      final foundationIndex = (-sourcePileIndex - 2);  // Convert back to 0-3 range
      final draggedCard = foundationPiles[foundationIndex].last;
      final targetCard = tableauPiles[targetPileIndex].isNotEmpty ? 
                      tableauPiles[targetPileIndex].last : null;
      
      if (canDropCard(draggedCard, targetCard)) {
        setState(() {
          // Move card from foundation to tableau
          tableauPiles[targetPileIndex].add(foundationPiles[foundationIndex].removeLast());
          revealedCards[targetPileIndex].add(true);  // New card is always revealed
        });
      }
      return;
    }

    // Don't do anything if dropping on the same pile
    if (sourcePileIndex == targetPileIndex) return;
    
    // Handle tableau to tableau moves
    final draggedCard = tableauPiles[sourcePileIndex][sourceCardIndex];
    final targetCard = tableauPiles[targetPileIndex].isNotEmpty ? 
                     tableauPiles[targetPileIndex].last : null;
    
    if (canDropCard(draggedCard, targetCard)) {
      setState(() {
        // Move the card and all cards above it
        final cardsToMove = tableauPiles[sourcePileIndex].sublist(sourceCardIndex);
        final revealedStatesToMove = revealedCards[sourcePileIndex].sublist(sourceCardIndex);
        
        // Remove cards from source pile
        tableauPiles[sourcePileIndex].removeRange(sourceCardIndex, tableauPiles[sourcePileIndex].length);
        revealedCards[sourcePileIndex].removeRange(sourceCardIndex, revealedCards[sourcePileIndex].length);
        
        // Add cards to target pile
        tableauPiles[targetPileIndex].addAll(cardsToMove);
        revealedCards[targetPileIndex].addAll(revealedStatesToMove);
        
        // Reveal the new top card of the source pile if it exists
        if (tableauPiles[sourcePileIndex].isNotEmpty) {
          revealedCards[sourcePileIndex][revealedCards[sourcePileIndex].length - 1] = true;
        }
      });
    }
  }

  // Update the canDropOnFoundation method to enforce suit order
  bool canDropOnFoundation(Card draggedCard, int foundationIndex) {
    // Check if the card matches the designated suit for this foundation pile
    if (draggedCard.suit != foundationSuitOrder[foundationIndex]) {
      return false;
    }

    if (foundationPiles[foundationIndex].isEmpty) {
      return draggedCard.rank == Rank.ace;  // Only aces can start a foundation pile
    }
    
    Card topCard = foundationPiles[foundationIndex].last;
    return draggedCard.suit == topCard.suit &&  // Must be same suit
           draggedCard.rank.index == topCard.rank.index + 1;  // Must be next rank up
  }

  // Update the findValidFoundationPile method to respect suit order
  int? findValidFoundationPile(Card card) {
    // Find the correct foundation index for this suit
    int foundationIndex = foundationSuitOrder.indexOf(card.suit);
    if (foundationIndex != -1 && canDropOnFoundation(card, foundationIndex)) {
      return foundationIndex;
    }
    return null;
  }

  // Add this method to try moving a card to foundation
  void tryMoveToFoundation(Card card, int sourcePileIndex, int sourceCardIndex) {
    int? foundationIndex = findValidFoundationPile(card);
    if (foundationIndex != null) {
      handleFoundationDrop(foundationIndex, sourcePileIndex, sourceCardIndex);
    }
  }

  void checkWin() {
    // Check if all foundation piles have 13 cards (complete suits)
    bool isWin = foundationPiles.every((pile) => pile.length == 13);
    if (isWin && !showWinAnimation) {
      setState(() {
        showWinAnimation = true;
      });
      // Reset animation after a few seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            showWinAnimation = false;
          });
        }
      });
    }
  }

  // Call checkWin after every successful move to foundation
  void handleFoundationDrop(int foundationIndex, int sourcePileIndex, int sourceCardIndex) {
    setState(() {
      if (sourcePileIndex == -1) {
        // Moving from waste pile
        foundationPiles[foundationIndex].add(wastePile.removeAt(0));
      } else {
        // Moving from tableau
        foundationPiles[foundationIndex].add(tableauPiles[sourcePileIndex].removeLast());
        revealedCards[sourcePileIndex].removeLast();
        
        // Reveal new top card if any
        if (tableauPiles[sourcePileIndex].isNotEmpty) {
          revealedCards[sourcePileIndex][revealedCards[sourcePileIndex].length - 1] = true;
        }
      }
    });
    checkWin();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background decoration
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green[800]!,
                Colors.green[600]!,
              ],
            ),
            image: const DecorationImage(
              image: NetworkImage('https://www.transparenttextures.com/patterns/felt.png'),
              repeat: ImageRepeat.repeat,
            ),
          ),
        ),
        // Game content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Check if device is in portrait mode
                final isPortrait = constraints.maxHeight > constraints.maxWidth;
                
                if (isPortrait) {
                  return Container(
                    color: Colors.black87,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.screen_rotation,
                              color: Colors.white,
                              size: 96,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Please rotate your device',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Solitaire works best in landscape mode',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 24,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Calculate card dimensions based on screen size
                final cardWidth = constraints.maxWidth < 750 ? 
                    constraints.maxWidth / 9 : // For smaller screens
                    140.0; // Increased from 100.0 for larger screens
                final cardHeight = cardWidth * 1.5;
                final cardSpacing = constraints.maxWidth < 750 ?
                    constraints.maxWidth / 45 : // For smaller screens
                    24.0; // Increased from 16.0 for larger screens
                final verticalSpacing = cardHeight * 0.25; // Increased from 0.2 for more spacing between stacked cards

                // Calculate maximum height needed for the game
                final maxCardsInColumn = 13; // Maximum possible cards in a tableau column
                final totalHeightNeeded = cardHeight + (maxCardsInColumn * verticalSpacing);
                
                // If the needed height is more than available height, scale everything down
                final scale = totalHeightNeeded > (constraints.maxHeight - cardSpacing * 2) ?
                    (constraints.maxHeight - cardSpacing * 2) / totalHeightNeeded :
                    1.0;
                
                final scaledCardWidth = cardWidth * scale;
                final scaledCardHeight = cardHeight * scale;
                final scaledVerticalSpacing = verticalSpacing * scale;
                final scaledCardSpacing = cardSpacing * scale;

                // Create layout info
                layoutInfo = TableauLayoutInfo(
                  cardWidth: scaledCardWidth,
                  cardHeight: scaledCardHeight,
                  cardSpacing: scaledCardSpacing,
                  verticalSpacing: scaledVerticalSpacing,
                  constraints: constraints,
                );

                return Padding(
                  padding: EdgeInsets.all(scaledCardSpacing),
                  child: Stack(
                    children: [
                      // Top row with deck and foundation piles
                      SizedBox(
                        height: scaledCardHeight * 1.2,
                        child: Row(
                          children: [
                            // Deck
                            Container(
                              width: scaledCardWidth,
                              height: scaledCardHeight,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white30, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: GestureDetector(
                                onTap: drawCard,
                                child: deck.isNotEmpty
                                  ? PlayingCard(
                                      isFaceUp: false,
                                      width: scaledCardWidth,
                                      height: scaledCardHeight,
                                    )
                                  : wastePile.isNotEmpty 
                                    ? Center(
                                        child: Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.white70,
                                          size: 48 * scale,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            SizedBox(width: cardSpacing),
                            // Waste pile
                            Container(
                              width: scaledCardWidth,
                              height: scaledCardHeight,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white30, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: wastePile.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      // Try to move top waste card to foundation
                                      tryMoveToFoundation(
                                        wastePile.first,
                                        -1,  // Special indicator for waste pile
                                        0
                                      );
                                    },
                                    child: Draggable<Map<String, dynamic>>(
                                      data: {
                                        'pile': -1,  // Special indicator for waste pile
                                        'index': wastePile.length - 1,
                                      },
                                      feedback: PlayingCard(
                                        card: wastePile.first,
                                        isFaceUp: true,
                                        width: scaledCardWidth,
                                        height: scaledCardHeight,
                                      ),
                                      childWhenDragging: wastePile.length > 1
                                        ? PlayingCard(
                                            card: wastePile[1],
                                            isFaceUp: true,
                                            width: scaledCardWidth,
                                            height: scaledCardHeight,
                                          )
                                        : const SizedBox.shrink(),
                                      child: PlayingCard(
                                        card: wastePile.first,
                                        isFaceUp: true,
                                        width: scaledCardWidth,
                                        height: scaledCardHeight,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            ),
                            const Spacer(),
                            // Foundation piles
                            ...List.generate(4, (index) => Padding(
                              padding: EdgeInsets.only(left: scaledCardSpacing),
                              child: DragTarget<Map<String, dynamic>>(
                                onWillAccept: (data) {
                                  if (data == null) return false;
                                  final sourcePileIndex = data['pile'] as int;
                                  final sourceCardIndex = data['index'] as int;
                                  final draggedCard = sourcePileIndex == -1 ? 
                                                   wastePile.first : 
                                                   tableauPiles[sourcePileIndex][sourceCardIndex];
                                  return canDropOnFoundation(draggedCard, index);
                                },
                                onAccept: (data) {
                                  final sourcePileIndex = data['pile'] as int;
                                  final sourceCardIndex = data['index'] as int;
                                  handleFoundationDrop(index, sourcePileIndex, sourceCardIndex);
                                },
                                builder: (context, candidateData, rejectedData) {
                                  return Container(
                                    width: scaledCardWidth,
                                    height: scaledCardHeight,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: candidateData.isNotEmpty ? Colors.yellow : Colors.white30,
                                        width: candidateData.isNotEmpty ? 3 : 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: foundationPiles[index].isNotEmpty ? 
                                      Draggable<Map<String, dynamic>>(
                                        data: {
                                          'pile': -2 - index,  // Special indicator for foundation piles (-2, -3, -4, -5)
                                          'index': foundationPiles[index].length - 1,
                                        },
                                        feedback: PlayingCard(
                                          card: foundationPiles[index].last,
                                          isFaceUp: true,
                                          width: scaledCardWidth,
                                          height: scaledCardHeight,
                                        ),
                                        child: PlayingCard(
                                          card: foundationPiles[index].last,
                                          isFaceUp: true,
                                          width: scaledCardWidth,
                                          height: scaledCardHeight,
                                        ),
                                      ) : Stack(
                                      children: [
                                        if (candidateData.isNotEmpty)
                                          Center(
                                            child: Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.yellow,
                                              size: 48 * scale,
                                            ),
                                          ),
                                        Center(
                                          child: Text(
                                            foundationSuitOrder[index].toString() == 'Suit.hearts' ? '♥' :
                                            foundationSuitOrder[index].toString() == 'Suit.diamonds' ? '♦' :
                                            foundationSuitOrder[index].toString() == 'Suit.clubs' ? '♣' : '♠',
                                            style: TextStyle(
                                              fontSize: 48 * scale,
                                              color: foundationSuitOrder[index] == Suit.hearts || 
                                                    foundationSuitOrder[index] == Suit.diamonds ? 
                                                    Colors.red.withOpacity(0.5) : 
                                                    Colors.black.withOpacity(0.5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            )),
                          ],
                        ),
                      ),
                      // Tableau piles - remove the Column and Expanded
                      TableauLayout(
                        layoutInfo: layoutInfo,
                        tableauPiles: tableauPiles,
                        revealedCards: revealedCards,
                        draggedCard: draggedCard,
                        onDrop: handleCardDrop,
                        onCardTap: (pileIndex, cardIndex) {
                          if (cardIndex == tableauPiles[pileIndex].length - 1) {
                            if (!revealedCards[pileIndex][cardIndex]) {
                              revealCard(pileIndex);
                            } else {
                              tryMoveToFoundation(
                                tableauPiles[pileIndex][cardIndex],
                                pileIndex,
                                cardIndex
                              );
                            }
                          }
                        },
                        onDragStarted: (pileIndex, cardIndex) {
                          setState(() {
                            draggedCard = {
                              'pile': pileIndex,
                              'index': cardIndex,
                            };
                          });
                        },
                        onDragEnd: () {
                          setState(() {
                            draggedCard = null;
                          });
                        },
                        wastePile: wastePile,
                      ),
                      if (isDealing)
                        DealingAnimation(
                          layoutInfo: layoutInfo,
                          cardsToAnimate: cardsToAnimate,
                          cardsFaceUp: cardsFaceUp,
                          dealingControllers: dealingControllers,
                          dealingAnimations: dealingAnimations,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (showWinAnimation)
          // Enhanced win animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Container(
                color: Colors.black54.withOpacity(0.7 * value),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5 * value, sigmaY: 5 * value),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: value,
                          child: const Text(
                            '🎉 Congratulations! 🎉',
                            style: TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Transform.scale(
                          scale: value,
                          child: const Text(
                            'You won!',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Transform.scale(
                          scale: value,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                showWinAnimation = false;
                                initializeGame();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.black54,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class PlayingCard extends StatelessWidget {
  final Card? card;
  final bool isFaceUp;
  final double? width;
  final double? height;
  
  const PlayingCard({
    super.key,
    this.card,
    required this.isFaceUp,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final actualWidth = width ?? 80.0;
    final actualHeight = height ?? 120.0;
    final scale = actualWidth / 80.0; // Base scale factor

    return Container(
      width: actualWidth,
      height: actualHeight,
      decoration: BoxDecoration(
        color: isFaceUp ? Colors.white : Colors.blue[900],
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: Colors.white, width: 1 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
        gradient: !isFaceUp ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[900]!,
            Colors.blue[800]!,
          ],
        ) : null,
      ),
      child: isFaceUp && card != null
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8 * scale),
              color: Colors.white,
            ),
            padding: EdgeInsets.all(4.0 * scale),
            child: Stack(
              children: [
                // Card background pattern
                Center(
                  child: Text(
                    card!.suitString,
                    style: TextStyle(
                      fontSize: 72 * scale,  // Scale the center suit icon
                      color: card!.isRed ? 
                        Colors.red.withOpacity(0.1) : 
                        Colors.black.withOpacity(0.1),
                    ),
                  ),
                ),
                // Top-left rank and suit
                Text(
                  '${card!.rankString}${card!.suitString}',
                  style: TextStyle(
                    fontSize: 24 * scale,  // Scale the corner text
                    fontWeight: FontWeight.bold,
                    color: card!.isRed ? Colors.red : Colors.black,
                    height: 1,
                  ),
                ),
                // Bottom-right rank and suit (rotated 180°)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Transform.rotate(
                    angle: 3.14159,
                    child: Text(
                      '${card!.rankString}${card!.suitString}',
                      style: TextStyle(
                        fontSize: 24 * scale,  // Scale the corner text
                        fontWeight: FontWeight.bold,
                        color: card!.isRed ? Colors.red : Colors.black,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8 * scale),
              gradient: LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: const DecorationImage(
                image: NetworkImage('https://www.transparenttextures.com/patterns/diamond-upholstery.png'),
                repeat: ImageRepeat.repeat,
                opacity: 0.1,
              ),
            ),
            child: Center(
              child: Text(
                '♠',
                style: TextStyle(
                  color: Colors.blue[200],
                  fontSize: 32 * scale,  // Scale the back icon
                ),
              ),
            ),
          ),
    );
  }
}

// Add new classes for layout management
class TableauLayoutInfo {
  final double cardWidth;
  final double cardHeight;
  final double cardSpacing;
  final double verticalSpacing;
  final BoxConstraints constraints;

  TableauLayoutInfo({
    required this.cardWidth,
    required this.cardHeight,
    required this.cardSpacing,
    required this.verticalSpacing,
    required this.constraints,
  });

  Offset getPilePosition(int pileIndex) {
    final availableWidth = constraints.maxWidth - (2 * cardSpacing);
    final totalCardWidth = cardWidth * 7;
    final remainingSpace = availableWidth - totalCardWidth;
    final evenSpace = remainingSpace / 8;
    
    final x = cardSpacing + (evenSpace + (cardWidth + evenSpace) * pileIndex);
    final y = cardHeight * 1.2 + cardSpacing;  // Align with top row height
    
    return Offset(x, y);
  }

  Offset getCardPosition(int pileIndex, int cardIndex) {
    final pilePos = getPilePosition(pileIndex);
    return Offset(pilePos.dx, pilePos.dy + cardIndex * verticalSpacing);
  }

  Offset getDeckPosition() {
    return Offset(cardSpacing, 0);  // Align with top row
  }
}

class TableauLayout extends StatelessWidget {
  final TableauLayoutInfo layoutInfo;
  final List<List<Card>> tableauPiles;
  final List<List<bool>> revealedCards;
  final Map<String, int>? draggedCard;
  final Function(Map<String, dynamic>, int) onDrop;
  final Function(int, int) onCardTap;
  final Function(int, int) onDragStarted;
  final Function() onDragEnd;
  final List<Card> wastePile;

  const TableauLayout({
    super.key,
    required this.layoutInfo,
    required this.tableauPiles,
    required this.revealedCards,
    required this.draggedCard,
    required this.onDrop,
    required this.onCardTap,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.wastePile,
  });

  bool canDropCard(Card draggedCard, Card? targetCard) {
    if (targetCard == null) {
      return true; // Allow any card to be placed on empty spots
    }
    
    // Check if cards are alternate colors and sequential
    return draggedCard.isRed != targetCard.isRed && 
           draggedCard.rank.index == targetCard.rank.index - 1;
  }

  bool canDragCard(int pileIndex, int cardIndex) {
    // Can drag if:
    // 1. The card is revealed AND
    // 2. All cards above it are also revealed
    if (!revealedCards[pileIndex][cardIndex]) return false;
    
    // Check if all cards above are revealed
    for (int i = cardIndex; i < tableauPiles[pileIndex].length; i++) {
      if (!revealedCards[pileIndex][i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scale = layoutInfo.cardWidth / 80.0;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Stack(
      children: List.generate(7, (pileIndex) {
        final pilePosition = layoutInfo.getPilePosition(pileIndex);
        
        return Positioned(
          left: pilePosition.dx,
          top: pilePosition.dy,
          child: DragTarget<Map<String, dynamic>>(
            onWillAccept: (data) {
              if (data == null) return false;
              final sourcePileIndex = data['pile'] as int;
              final sourceCardIndex = data['index'] as int;
              final draggedCard = sourcePileIndex == -1 ? 
                               wastePile.first : 
                               tableauPiles[sourcePileIndex][sourceCardIndex];
              
              if (tableauPiles[pileIndex].isEmpty) {
                return true;
              }
              
              final targetCard = tableauPiles[pileIndex].last;
              return canDropCard(draggedCard, targetCard);
            },
            onAccept: (data) => onDrop(data, pileIndex),
            builder: (context, candidateData, rejectedData) {
              return Stack(
                children: [
                  // Base container
                  Container(
                    width: layoutInfo.cardWidth,
                    height: tableauPiles[pileIndex].isEmpty ? 
                        layoutInfo.cardHeight : 
                        (tableauPiles[pileIndex].length * layoutInfo.verticalSpacing + layoutInfo.cardHeight),
                    decoration: BoxDecoration(
                      border: tableauPiles[pileIndex].isEmpty ? Border.all(
                        color: candidateData.isNotEmpty ? Colors.yellow : Colors.white30,
                        width: candidateData.isNotEmpty ? 3 : 1,
                      ) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: candidateData.isNotEmpty && tableauPiles[pileIndex].isEmpty ? Center(
                      child: Icon(
                        Icons.add_circle_outline,
                        color: Colors.yellow,
                        size: 48 * scale,
                      ),
                    ) : null,
                  ),
                  // Cards
                  ...List.generate(
                    tableauPiles[pileIndex].length,
                    (cardIndex) {
                      bool isRevealed = revealedCards[pileIndex][cardIndex];
                      bool isDragging = draggedCard != null && 
                          draggedCard!['pile'] == pileIndex && 
                          cardIndex >= draggedCard!['index']!;
                      
                      return Positioned(
                        top: cardIndex * layoutInfo.verticalSpacing,
                        child: SizedBox(
                          width: layoutInfo.cardWidth,
                          height: layoutInfo.cardHeight,
                          child: GestureDetector(
                            onTap: () {
                              onCardTap(pileIndex, cardIndex);
                            },
                            child: Draggable<Map<String, dynamic>>(
                              data: {
                                'pile': pileIndex,
                                'index': cardIndex,
                              },
                              feedback: isRevealed ? Material(
                                type: MaterialType.transparency,
                                color: Colors.transparent,
                                elevation: 0,
                                child: Container(
                                  width: layoutInfo.cardWidth,
                                  height: layoutInfo.cardHeight + 
                                    ((tableauPiles[pileIndex].length - cardIndex - 1) * layoutInfo.verticalSpacing),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      PlayingCard(
                                        card: tableauPiles[pileIndex][cardIndex],
                                        isFaceUp: true,
                                        width: layoutInfo.cardWidth,
                                        height: layoutInfo.cardHeight,
                                      ),
                                      // Only add cards above if this isn't the last card
                                      if (cardIndex < tableauPiles[pileIndex].length - 1)
                                        ...List.generate(
                                          tableauPiles[pileIndex].length - cardIndex - 1,
                                          (i) => Positioned(
                                            top: (i + 1) * layoutInfo.verticalSpacing,
                                            child: PlayingCard(
                                              card: tableauPiles[pileIndex][cardIndex + i + 1],
                                              isFaceUp: true,
                                              width: layoutInfo.cardWidth,
                                              height: layoutInfo.cardHeight,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ) : Container(),
                              dragAnchorStrategy: (draggable, context, position) {
                                final RenderBox renderObject = context.findRenderObject() as RenderBox;
                                final localPosition = renderObject.globalToLocal(position);
                                return Offset(
                                  localPosition.dx,
                                  localPosition.dy,
                                );
                              },
                              childWhenDragging: isRevealed ? Container(
                                width: layoutInfo.cardWidth,
                                height: layoutInfo.cardHeight,
                                color: Colors.transparent,
                              ) : Container(),
                              maxSimultaneousDrags: canDragCard(pileIndex, cardIndex) ? 1 : 0,
                              child: Opacity(
                                opacity: isDragging ? 0.0 : 1.0,
                                child: PlayingCard(
                                  card: tableauPiles[pileIndex][cardIndex],
                                  isFaceUp: isRevealed,
                                  width: layoutInfo.cardWidth,
                                  height: layoutInfo.cardHeight,
                                ),
                              ),
                              onDragStarted: () {
                                onDragStarted(pileIndex, cardIndex);
                              },
                              onDragEnd: (_) => onDragEnd(),  // Fix DragEndCallback type
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }
}

class DealingAnimation extends StatelessWidget {
  final TableauLayoutInfo layoutInfo;
  final List<Card> cardsToAnimate;
  final List<bool> cardsFaceUp;
  final List<AnimationController> dealingControllers;
  final List<Animation<Offset>> dealingAnimations;

  const DealingAnimation({
    super.key,
    required this.layoutInfo,
    required this.cardsToAnimate,
    required this.cardsFaceUp,
    required this.dealingControllers,
    required this.dealingAnimations,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(cardsToAnimate.length, (index) {
        return AnimatedBuilder(
          animation: dealingControllers[index],
          builder: (context, child) {
            final position = dealingAnimations[index].value;
            final deckPosition = layoutInfo.getDeckPosition();
            final targetPosition = layoutInfo.getCardPosition(
              position.dx.toInt(),
              position.dy.toInt(),
            );
            
            // Enhanced rotation calculation
            // More spins during arc, gradually settling to 0
            final progress = dealingControllers[index].value;
            final rotations = 2.0; // Number of full rotations during flight
            final rotation = progress < 0.8 
                ? (progress * rotations * 2 * 3.14159) 
                : ((1.0 - progress) * 5) * (rotations * 2 * 3.14159 % (2 * 3.14159)); // Settle to 0
            
            // Enhanced scale effect
            final scale = 1.0 + (0.15 * sin(progress * 3.14159)); // Smooth scale pulse
            
            return Positioned(
              left: deckPosition.dx + (targetPosition.dx - deckPosition.dx) * progress,
              top: deckPosition.dy + (targetPosition.dy - deckPosition.dy) * progress,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002) // Slightly enhanced perspective
                  ..rotateZ(rotation)
                  ..scale(scale),
                alignment: Alignment.center,
                child: SizedBox(
                  width: layoutInfo.cardWidth,
                  height: layoutInfo.cardHeight,
                  child: PlayingCard(
                    card: cardsToAnimate[index],
                    isFaceUp: cardsFaceUp[index] && progress > 0.6,
                    width: layoutInfo.cardWidth,
                    height: layoutInfo.cardHeight,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
