package DataCenter;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.PostConstruct;
import javax.annotation.Resource;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import javax.ejb.Timeout;
import javax.ejb.Timer;
import javax.ejb.TimerService;



@Startup
@Singleton
public class GetDataBean {

    @EJB
WorkingBean Working;
@EJB
Requests2Bean Requests2;
@EJB
ChargingBean Charging;
@EJB
Requests3Bean Requests3;
@EJB
ReturnBean Return;


    @Resource
    TimerService timerService;
    long duration = 5;

    Map<String, Boolean> inputs = new HashMap<String, Boolean>();
    String name = "GetData";
    boolean inWork = false;
    boolean waiting4Check = false;


    @PostConstruct
    void init() {
        inputs.put("Working", false);
inputs.put("Requests2", false);

    }

    public void reciveNotification(String name, Boolean status) {
        inputs.put(name, status);
        checkInputs();
    }

    @Timeout
    public void timeout() {
        waiting4Check = false;
        checkInputs();
    }

    private void checkInputs()
    {
        if(inWork)
        {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
            return;
        }

        inWork = true;
        boolean inputsFull = true;
        List<Boolean> list =  new ArrayList<Boolean>(inputs.values());
        for(int i = 0; i < inputs.size(); i++)
        {
            inputsFull = inputsFull && list.get(i);
        }

        if(inputsFull)
        {
            triggerTransition();
        }

        inWork = false;
    }

    private void triggerTransition() {
        if (blockInputs() && checkExtra()) {

          boolean fullSynch = true;
            List<String> synch = new ArrayList<String>();
            List<String> keys = new ArrayList<String>();keys = Working.getTokens();
                       fullSynch = false;
                       for(int i = 0; i<keys.size(); i++)
                       {
                           if(Return.synchronize(keys.get(i), name))
                           {
                              synch.add(keys.get(i));
                               fullSynch = true;
                               break;
                           }
                       }
                       if(!fullSynch)
                       {
                           synch.add("");
                       }fullSynch = true;
                     for(int i = 0; i<synch.size(); i++)
                         if(synch.get(i).equals(""))
                             fullSynch = false;

                     if(fullSynch)
                     {
                          String token;Return.triggerTransition(synch.get(0));
token = Requests2.getFirstToken();
Requests2.removeToken(token);
Requests3.createToken();
token = synch.get(0);
Working.removeToken(token);
Charging.addToken(token);
doExtraStuff();
                     unblockInputs();
                 } else {Return.removeSynchronization(synch.get(0), name);
if (!waiting4Check) {
                        Timer timer = timerService.createTimer(duration, null);
                        waiting4Check = true;
                     }
                     unblockInputs();
                }

        } else {
            if (!waiting4Check) {
                Timer timer = timerService.createTimer(duration, null);
                waiting4Check = true;
            }
        }
    }

    private boolean blockInputs() {
        boolean blocked = true;
        blocked = blocked && Working.blockPosition(name) && Requests2.blockPosition(name);

        if (!blocked) {
            unblockInputs();
        }

        return blocked;
    }

    private void unblockInputs()
    {
        Working.unblockPosition(name);
Requests2.unblockPosition(name);

    }
    private boolean checkExtra() {
        return true;

    }

    private void doExtraStuff() {
        
    }

}
