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
public class StartBean {

    @EJB
Requests1Bean Requests1;
@EJB
IdleBean Idle;
@EJB
WorkingBean Working;
@EJB
Requests2Bean Requests2;
@EJB
GetTaskBean GetTask;


    @Resource
    TimerService timerService;
    long duration = 5;

    Map<String, Boolean> inputs = new HashMap<String, Boolean>();
    String name = "Start";
    boolean inWork = false;
    boolean waiting4Check = false;


    @PostConstruct
    void init() {
        inputs.put("Requests1", false);
inputs.put("Idle", false);

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
            List<String> keys = new ArrayList<String>();keys = Idle.getTokens();
                       fullSynch = false;
                       for(int i = 0; i<keys.size(); i++)
                       {
                           if(GetTask.synchronize(keys.get(i), name))
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
                          String token;GetTask.triggerTransition(synch.get(0));
token = Requests1.getFirstToken();
Requests1.removeToken(token);
Requests2.createToken();
token = synch.get(0);
Idle.removeToken(token);
Working.addToken(token);
doExtraStuff();
                     unblockInputs();
                 } else {GetTask.removeSynchronization(synch.get(0), name);
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
        blocked = blocked && Requests1.blockPosition(name) && Idle.blockPosition(name);

        if (!blocked) {
            unblockInputs();
        }

        return blocked;
    }

    private void unblockInputs()
    {
        Requests1.unblockPosition(name);
Idle.unblockPosition(name);

    }
    private boolean checkExtra() {
        return true;

    }

    private void doExtraStuff() {
        
    }

}
