import 'package:flutter/material.dart';

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
      home: const GameBoard(),
    );
  }
}

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  late List<List<Card>> tableauPiles;
  late List<Card> deck;
  List<Card> wastePile = [];
  List<List<bool>> revealedCards = List.generate(7, (_) => []); // Track revealed state
  List<List<Card>> foundationPiles = List.generate(4, (_) => []);
  Map<String, int>? draggedCard;  // Add this property
  bool showWinAnimation = false;

  @override
  void initState() {
    super.initState();
    initializeGame();
  }

  // Add this getter for the foundation suit order
  List<Suit> get foundationSuitOrder => [Suit.clubs, Suit.spades, Suit.hearts, Suit.diamonds];

  void initializeGame() {
    // Create and shuffle the deck
    deck = [];
    for (var suit in Suit.values) {
      for (var rank in Rank.values) {
        deck.add(Card(suit, rank));
      }
    }
    deck.shuffle();

    // Initialize tableau piles
    tableauPiles = List.generate(7, (index) => []);
    revealedCards = List.generate(7, (index) => []); // Reset revealed cards state
    // Initialize foundation piles in the specific order
    foundationPiles = List.generate(4, (_) => []);
    
    for (int i = 0; i < 7; i++) {
      for (int j = i; j < 7; j++) {
        tableauPiles[j].add(deck.removeLast());
        // Initialize revealed state (true for top cards)
        revealedCards[j].add(j == i);
      }
    }
  }

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
        Scaffold(
          appBar: AppBar(
            title: const Text('Solitaire'),
            backgroundColor: Colors.green[700],
          ),
          backgroundColor: Colors.green,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 64.0, 16.0, 16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      // Top row with deck and foundation piles
                      SizedBox(
                        height: constraints.maxHeight * 0.2,
                        child: Row(
                          children: [
                            // Deck
                            Container(
                              width: 80,
                              height: 120,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white30, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: GestureDetector(
                                onTap: drawCard,
                                child: deck.isNotEmpty
                                  ? PlayingCard(isFaceUp: false)
                                  : wastePile.isNotEmpty 
                                    ? const Center(
                                        child: Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.white70,
                                          size: 32,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Waste pile
                            Container(
                              width: 80,
                              height: 120,
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
                                      ),
                                      childWhenDragging: wastePile.length > 1
                                        ? PlayingCard(
                                            card: wastePile[1],
                                            isFaceUp: true,
                                          )
                                        : const SizedBox.shrink(),
                                      child: PlayingCard(
                                        card: wastePile.first,
                                        isFaceUp: true,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            ),
                            const Spacer(),
                            // Foundation piles
                            ...List.generate(4, (index) => Padding(
                              padding: const EdgeInsets.only(left: 16),
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
                                    width: 80,
                                    height: 120,
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
                                        ),
                                        child: PlayingCard(
                                          card: foundationPiles[index].last,
                                          isFaceUp: true,
                                        ),
                                      ) : Stack(
                                      children: [
                                        if (candidateData.isNotEmpty)
                                          const Center(
                                            child: Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.yellow,
                                              size: 32,
                                            ),
                                          ),
                                        Center(
                                          child: Text(
                                            foundationSuitOrder[index].toString() == 'Suit.hearts' ? '♥' :
                                            foundationSuitOrder[index].toString() == 'Suit.diamonds' ? '♦' :
                                            foundationSuitOrder[index].toString() == 'Suit.clubs' ? '♣' : '♠',
                                            style: TextStyle(
                                              fontSize: 32,
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
                      const SizedBox(height: 32),
                      // Tableau piles
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(7, (pileIndex) {
                            return DragTarget<Map<String, dynamic>>(
                              onWillAccept: (data) {
                                if (data == null) return false;
                                final sourcePileIndex = data['pile'] as int;
                                final sourceCardIndex = data['index'] as int;
                                final draggedCard = sourcePileIndex == -1 ? 
                                                   wastePile.first : 
                                                   tableauPiles[sourcePileIndex][sourceCardIndex];
                                
                                // If pile is empty, accept any card
                                if (tableauPiles[pileIndex].isEmpty) {
                                  return true;
                                }
                                
                                final targetCard = tableauPiles[pileIndex].last;
                                return canDropCard(draggedCard, targetCard);
                              },
                              onAccept: (data) => handleCardDrop(data, pileIndex),
                              builder: (context, candidateData, rejectedData) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Base container with drop indicator
                                    Container(
                                      width: 80,
                                      height: tableauPiles[pileIndex].isEmpty ? 120 : (tableauPiles[pileIndex].length * 20.0 + 120),
                                      decoration: BoxDecoration(
                                        border: tableauPiles[pileIndex].isEmpty ? Border.all(
                                          color: candidateData.isNotEmpty ? Colors.yellow : Colors.white30,
                                          width: candidateData.isNotEmpty ? 3 : 1,
                                        ) : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: candidateData.isNotEmpty && tableauPiles[pileIndex].isEmpty ? const Center(
                                        child: Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.yellow,
                                          size: 32,
                                        ),
                                      ) : null,
                                    ),
                                    // Cards
                                    ...List.generate(
                                      tableauPiles[pileIndex].length,
                                      (cardIndex) {
                                        bool isRevealed = revealedCards[pileIndex][cardIndex];
                                        bool isDragging = false;
                                        
                                        // Check if this card is part of a dragged stack
                                        if (draggedCard != null && 
                                            draggedCard!['pile'] == pileIndex && 
                                            cardIndex >= draggedCard!['index']!) {
                                          isDragging = true;
                                        }
                                        
                                        return Positioned(
                                          top: cardIndex * 20.0,
                                          child: SizedBox(
                                            width: 80,
                                            height: 120,
                                            child: GestureDetector(
                                              onTap: () {
                                                if (cardIndex == tableauPiles[pileIndex].length - 1) {
                                                  if (!isRevealed) {
                                                    revealCard(pileIndex);
                                                  } else {
                                                    // Try to move revealed top card to foundation
                                                    tryMoveToFoundation(
                                                      tableauPiles[pileIndex][cardIndex],
                                                      pileIndex,
                                                      cardIndex
                                                    );
                                                  }
                                                }
                                              },
                                              child: Draggable<Map<String, dynamic>>(
                                                data: {
                                                  'pile': pileIndex,
                                                  'index': cardIndex,
                                                },
                                                feedback: isRevealed ? Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    PlayingCard(
                                                      card: tableauPiles[pileIndex][cardIndex],
                                                      isFaceUp: true,
                                                    ),
                                                    // Only add cards above if this isn't the last card
                                                    if (cardIndex < tableauPiles[pileIndex].length - 1)
                                                      ...List.generate(
                                                        tableauPiles[pileIndex].length - cardIndex - 1,
                                                        (i) => Positioned(
                                                          top: (i + 1) * 20.0,
                                                          child: PlayingCard(
                                                            card: tableauPiles[pileIndex][cardIndex + i + 1],
                                                            isFaceUp: true,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ) : Container(),
                                                childWhenDragging: isRevealed ? Container(
                                                  width: 80,
                                                  height: tableauPiles[pileIndex].length * 20.0 + 120,
                                                  color: Colors.transparent,
                                                ) : Container(),
                                                dragAnchorStrategy: (draggable, context, dragPosition) {
                                                  final RenderBox renderObject = context.findRenderObject() as RenderBox;
                                                  final localPosition = renderObject.globalToLocal(dragPosition);
                                                  return localPosition;
                                                },
                                                maxSimultaneousDrags: canDragCard(pileIndex, cardIndex) ? 1 : 0,
                                                child: Opacity(
                                                  opacity: isDragging ? 0.0 : 1.0,
                                                  child: PlayingCard(
                                                    card: tableauPiles[pileIndex][cardIndex],
                                                    isFaceUp: isRevealed,
                                                  ),
                                                ),
                                                onDragStarted: () {
                                                  setState(() {
                                                    draggedCard = {
                                                      'pile': pileIndex,
                                                      'index': cardIndex,
                                                    };
                                                  });
                                                },
                                                onDragEnd: (_) {
                                                  setState(() {
                                                    draggedCard = null;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (showWinAnimation)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '🎉 Congratulations! 🎉',
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You won!',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        showWinAnimation = false;
                        initializeGame();
                      });
                    },
                    child: const Text('Play Again'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class PlayingCard extends StatelessWidget {
  final Card? card;
  final bool isFaceUp;
  
  const PlayingCard({
    super.key,
    this.card,
    required this.isFaceUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: isFaceUp ? Colors.white : Colors.blue[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isFaceUp && card != null
        ? Padding(
            padding: const EdgeInsets.all(4.0),
            child: Stack(
              children: [
                // Top-left rank and suit
                Text(
                  '${card!.rankString}${card!.suitString}',
                  style: TextStyle(
                    fontSize: 18,
                    color: card!.isRed ? Colors.red : Colors.black,
                    height: 1,
                  ),
                ),
                // Bottom-right rank and suit (rotated 180°)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Transform.rotate(
                    angle: 3.14159, // 180 degrees in radians
                    child: Text(
                      '${card!.rankString}${card!.suitString}',
                      style: TextStyle(
                        fontSize: 18,
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
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
    );
  }
}
