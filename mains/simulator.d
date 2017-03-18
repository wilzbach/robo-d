import robo.simserver;
import robo.client;
import robo.iclient;
import robo.gamekeeper;

import std.algorithm;
import std.random;
import vibe.core.log;

void main()
{
    double START_X = 640;
    double START_Y = 480;
    double ROBOT_R = 15;

    auto rnd = Random(42);

    //auto robo = new TimeDecorator(new HackBackSimulator(START_X, START_Y, ROBOT_R));
    auto robo = new TimeDecorator!(typeof(rnd))(new HackBackSimulator(START_X, START_Y, ROBOT_R));
    robo.rnd = rnd;
    robo.withRandom = true;

    //auto robo = new HackBackSimulator(START_X, START_Y, ROBOT_R);
    IRoboClient client = new NaiveRoboClient();
    client.init(robo);

    // keep track of the world
    auto game = new Game!(typeof(rnd))(rnd);
    //logDebug("points: %s", game.points);

    int maxTicks = 800; // 120 / 0.15

    // set robot to the center
    robo.position.x = game.xCenter;
    robo.position.y = game.yCenter;
    robo.position.r = game.radius;

    logDebug("points: %s", game.points);

    //maxTicks = 800;
    maxTicks = 20;
    foreach (i; 0..maxTicks)
    {
        robo.tick();

        auto pos = robo.position();

        GameState gameState = {
            robo: pos,
            points: game.points,
            world: game.world,
        };
        // only send ticks every 100 ms
        // a tick is 15ms
        if (i % 6)
        {
            client.onRoboState(robo.state);
            client.onGameState(gameState);
        }

        // check the game board for reached points
        game.check(pos);
        //logDebug("robot: %s", pos);

        if (game.points.filter!(p => p.score > 0 && !p.collected).empty)
            break;
    }
    logDebug("total score: %s", game.score);
    //logDebug("points: %s", game.points);
}
