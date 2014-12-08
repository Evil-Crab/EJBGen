package DataCenter;

import java.util.ArrayList;
import java.util.List;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;

import javax.ejb.Singleton;
import javax.ejb.Startup;


@Startup
@Singleton
public class DroneManagerBean {

    @EJB
WaitingBean Waiting;
@EJB
StartingBean Starting;
@EJB
SearchingBean Searching;
@EJB
ReadingBean Reading;
@EJB
ReturningBean Returning;
@EJB
GetTaskBean GetTask;
@EJB
SearchDataBean SearchData;
@EJB
ReadDataBean ReadData;
@EJB
ReturnBean Return;
@EJB
ResetBean Reset;


    List<String> list = new ArrayList<String>();
    String type = "net";
    String name = "Drone";
    Integer idCounter = 0;
    Integer activeNets;

    @PostConstruct
    void init() {
        activeNets = 0;
    }

    public String createToken(String markup) {
        idCounter++;
        String token = (type + "_" + name + "_" + idCounter);

        Waiting.createNetToken(token);
Starting.createNetToken(token);
Searching.createNetToken(token);
Reading.createNetToken(token);
Returning.createNetToken(token);
GetTask.createNetToken(token);
SearchData.createNetToken(token);
ReadData.createNetToken(token);
Return.createNetToken(token);
Reset.createNetToken(token);



    if(markup.equals("291482"))
                        {
Waiting.createToken(token);
}

        activeNets++;

        return token;
    }

    public void removeToken(String id) {
        activeNets--;
        Waiting.destroyNetToken(id);
Starting.destroyNetToken(id);
Searching.destroyNetToken(id);
Reading.destroyNetToken(id);
Returning.destroyNetToken(id);
GetTask.destroyNetToken(id);
SearchData.destroyNetToken(id);
ReadData.destroyNetToken(id);
Return.destroyNetToken(id);
Reset.destroyNetToken(id);

    }

    public Integer getActiveNets()
    {
        return activeNets;
    }
}
